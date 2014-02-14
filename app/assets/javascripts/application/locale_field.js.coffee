# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

root = exports ? this

# @private
getObjectClass = (obj) ->
  if obj && obj.constructor && obj.constructor.toString
    arr = obj.constructor.toString().match(/function\s*(\w+)/)
    if arr && arr.length == 2
      return arr[1]
  return undefined

# @private
class XHash
  constructor: (@hash) ->
    @hash = @hash.hash if getObjectClass(@hash) == 'XHash'

  select: (func) ->
    result = {}
    (result[a] = b for own a, b of @hash when func(a, b))
    new XHash(result)

  reject: (func) ->
    result = {}
    (result[a] = b for own a, b of @hash when !func(a, b))
    new XHash(result)

  map: (func) ->
    result = {}
    (result[a] = func(a, b) for own a, b of @hash)
    new XHash(result)

  keys: -> new XArray(key for own key, value of @hash)

  delete: (obj) ->
    while (index = @hash.indexOf(obj)) >= 0
      @hash.splice index, 1
    this

# @private
class XArray
  constructor: (@array=null) ->
    @array ?= []
    @array = @array.array if getObjectClass(@array) == 'XArray'

  flatten: ->
    result = new XArray()
    for item in @array
      if getObjectClass(item) == 'XArray'
        result.array.push item.array...
      else if getObjectClass(item) == 'Array'
        result.array.push item...
      else
        result.array.push item
    result

  compact: -> new XArray(item for item in @array when item)
  select: (func) -> new XArray(item for item in @array when func(item))
  join: -> @array.join(arguments...)
  slice: -> new XArray(@array.slice(arguments...))
  map: (func) -> new XArray(func(item) for item in @array)
  delete: (filter) -> @array = (item for item in @array when item != filter); this

  any: (func) ->
    for item in @array
      return true if func(item)
    return false

String::startsWith = (other) -> this.indexOf(other) == 0

################################################################################

# @private Mostly a port of the Locale class in the Ruby code -- see that code
#   for comments.
class root.Locale
  constructor: (@iso639, @script, @extended_language=null, @region=null, @variants=null, @extensions=null) ->
    @iso639 = @iso639.toLowerCase()
    @region = @region.toUpperCase() if @region
    @extended_language = @extended_language.toLowerCase() if @extended_language

    @variants ?= []
    @variants = @variants.map (v) -> v.toLowerCase()
    @extensions ?= []

  rfc5646: -> new XArray([@iso639, @script, @extended_language, @region, @variants...]).compact().join('-')

  name: ->
    i18n_language = if @extended_language
      Locale.locales.extended[@iso639][@extended_language]
    else
      Locale.locales.name[@iso639]

    i18n_dialect = null
    if @variants.length > 0
      i18n_dialect = Locale.locales.variant[@iso639]
      i18n_dialect = i18n_dialect[variant] for variant in @variants
      i18n_dialect = i18n_dialect['_END_']

    i18n_script = if @script then Locale.locales.script[@script] else null
    i18n_region = if @region then Locale.locales.region[@region] else null

    if i18n_region && i18n_dialect && i18n_script
      Locale.locales.format.scripted_regional_dialectical.
        replace('%{script}', i18n_script).
        replace('%{dialect}', i18n_dialect).
        replace('%{region}', i18n_region).
        replace('%{language}', i18n_language)
    else if i18n_region && i18n_dialect
      Locale.locales.format.regional_dialectical.
        replace('%{dialect}', i18n_dialect).
        replace('%{region}', i18n_region).
        replace('%{language}', i18n_language)
    else if i18n_region && i18n_script
      Locale.locales.format.scripted_regional.
        replace('%{script}', i18n_script).
        replace('%{region}', i18n_region).
        replace('%{language}', i18n_language)
    else if i18n_dialect && i18n_script
      Locale.locales.format.scripted_dialectical.
        replace('%{script}', i18n_script).
        replace('%{dialect}', i18n_dialect).
        replace('%{language}', i18n_language)
    else if i18n_script
      Locale.locales.format.scripted.
        replace('%{script}', i18n_script).
       replace('%{language}', i18n_language)
    else if i18n_dialect
      Locale.locales.format.dialectical.
        replace('%{dialect}', i18n_dialect).
       replace('%{language}', i18n_language)
    else if i18n_region
      Locale.locales.format.regional.
        replace('%{region}', i18n_region).
        replace('%{language}', i18n_language)
    else
      i18n_language

  image: ->
    Locale.locale_countries[@region] || Locale.locale_countries[@iso639]

Locale.RFC5646_EXTLANG   = "(?<extlang>[a-zA-Z]{3})(-[a-zA-Z]{3}){0,2}"
Locale.RFC5646_ISO639    = "(?<iso639>[a-zA-Z]{2,3})(-#{Locale.RFC5646_EXTLANG})?"
Locale.RFC5646_RESERVED  = "(?<reserved>[a-zA-Z]{4})"
Locale.RFC5646_SUBTAG    = "(?<subtag>[a-zA-Z]{5,8})"
Locale.RFC5646_REGION    = "(?<region>([a-zA-Z]{2}|\\d{3}))"
Locale.RFC5646_VARIANT   = "([a-zA-Z0-9]{5,8}|\\d[a-zA-Z0-9]{3})"
Locale.RFC5646_SCRIPT    = "(?<script>[a-zA-Z]{4})"
Locale.RFC5646_EXTENSION = "([0-9A-WY-Za-wy-z](-[a-zA-Z0-9]{2,8}){1,})"
Locale.RFC5646_LOCALE  = "(#{Locale.RFC5646_ISO639}|#{Locale.RFC5646_RESERVED}|#{Locale.RFC5646_SUBTAG})"
Locale.RFC5646_PRIVATE   = "x(?<privates>(-[a-zA-Z0-9]{1,8}){1,})"
Locale.RFC5646_FORMAT    = XRegExp("^#{Locale.RFC5646_LOCALE}(-#{Locale.RFC5646_SCRIPT})?(-#{Locale.RFC5646_REGION})?(?<variants>(-#{Locale.RFC5646_VARIANT})*)(?<extensions>(-#{Locale.RFC5646_EXTENSION})*)(-#{Locale.RFC5646_PRIVATE})?$")

Locale.from_rfc5646 = (ident) ->
  return null unless (match = XRegExp.exec(ident, Locale.RFC5646_FORMAT))
  return null unless match.iso639
  if (variants = match.variants)
    variants = variants.split('-')
    variants.shift()
  if (extensions = match.extensions)
    extensions = extensions.split('-')
    extensions.shift()
  new Locale(match.iso639, match.script, match.extlang, match.region, variants || [], extensions || [])

Locale.from_rfc5646_prefix = (prefix, max=null) ->
  if prefix.indexOf('-') >= 0
    prefix_path = prefix.split('-')
    prefix = prefix_path.pop()
    parent_prefix = prefix_path.join('-')
    parent = this.from_rfc5646(parent_prefix)
    return [] unless parent

    search_paths = if parent.variants.length > 0
      #TODO subvariants
      new XArray()
    else if parent.region
      #TODO variants
      new XArray()
    else if parent.script
      new XArray(['region'])
    else
      new XArray(['region', 'script'])

    keys = search_paths.map((path) -> new XHash(Locale.locales[path]).select((k, v) -> Locale.matches_prefix(prefix, k, v)).keys()).flatten()
    keys.delete '_END_'
    keys = keys[0...max] if max
    return (Locale.from_rfc5646("#{parent_prefix}-#{key}") for key in keys.array)
  else
    keys = new XHash(Locale.locales.name).select((k, v) -> Locale.matches_prefix(prefix, k, v)).keys()
    keys = keys[0...max] if max
    return (Locale.from_rfc5646(key) for key in keys.array)

Locale.matches_prefix = (prefix, key, value) ->
  return false unless getObjectClass(value) == 'String'
  return true if key.toLowerCase().startsWith(prefix.toLowerCase())
  return true if new XArray(value.split(/\w+/)).any (word) -> word.toLowerCase().startsWith(prefix.toLowerCase())
  return false

Locale.locales = {}
Locale.locale_countries = {}

Locale.dataset = () -> 
  dataset = []
  for rfc, name of Locale.locales.name
    datum = 
      rfc: rfc
      name: name
      value: rfc
      flag: Locale.locale_countries[rfc]
      tokens: [ rfc, name]
    dataset.push datum
  return dataset


################################################################################

# A field where a user can input one or multiple locales as RFC 5646 codes.
# The field pops up a dialog offering autocomplete suggestions and the
# translation of locale codes into English names.
#
class root.LocaleField

  # Creates a new locale field. Must be applied to an `INPUT` element with the
  # class `locale-field` (and optionally `locale-field-list` to operate as a
  # comma-delimited list.
  #
  # Attaches event listeners to the field for keyboard operation of the menu.
  #
  # @param [jQuery element] element The element to apply locale field
  #   semantics to.
  #
  constructor: (@element, @options = {}) ->
    template = "
    <div class=\"locale-field-suggestion\">
      <img src=\"{{flag}}\" style=\"float: right;\">
      <div class='locale-rfc'>
        <strong>{{rfc}}</strong>
      </div> 
      <div class='locale-name'>
        {{name}}
      </span>
    </div>
    "
    
    @element.wrap("<span class='locale-field-wrapper'></span>")
    @element.typeahead 
      name: 'typeahead'
      local: Locale.dataset()
      template: template
      engine: Hogan

    @element.blur () -> 
      if $(this).val() == ''
        $(this).attr("placeholder", "Locale")
      else if Locale.from_rfc5646($(this).val()) == null
        $(this).val('')
        $(this).attr("placeholder", "Invalid Locale")

    this.setFlag()
    @element.on 'keyup', (e) =>
      this.setFlag()
    @element.on "typeahead:closed", (e) =>
      this.setFlag()


  setFlag: ->
    @element.parent().find('img.locale-flag').remove()
    image = Locale.from_rfc5646(@element.val())?.image()
    if image
      img = $('<img/>').attr('src', image).addClass('locale-flag').insertAfter(@element)
      img.css('top', (img.parent().height() - 24) / 2)

$.when($.ajax("/locales.json"), $.ajax("/locales/countries.json")).done (locales_result, countries_result) ->
  Locale.locales = locales_result[0]
  Locale.locale_countries = countries_result[0]

  $('input.locale-field').each (_, field) -> new LocaleField($(field))
  $(document).trigger 'locales_loaded'
  window.localesLoaded = true
