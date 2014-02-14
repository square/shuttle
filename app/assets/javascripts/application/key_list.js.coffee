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

# Displays a grid of keys under a commit and the translations of that key in
# each locale, intended for monitoring roles to view detailed information on
# the progress of a commit's translation process.
#
class root.KeyList

  # Creates a new key list manager for the given `TABLE` element.
  #
  # @param [jQuery element] table A `<TABLE>` to render keys and translations
  #   into.
  # @param [Object#fetch(Number[, Number])] dataSource Any object with a fetch
  #   method returning a promise resolving to a list of keys and translations.
  # @param [Object<String, Object>] locales The RFC 5646 codes of the locales to
  #   display, mapped to an object with the following keys: "required" (true if
  #   it's a required locale), "targeted" (true if it's a targeted locale), and
  #   "finished" (true if all translations in that locale are approved).
  # @param [String] @base_locale The RFC 5646 code of the project's base locale.
  #   This locale will be displayed first.
  #
  constructor: (@table, @dataSource, @locales, @base_locale) ->
    @setupTable()

    @scroll = @table.infiniteScroll @dataSource,
      windowScroll: true
      renderer: (keys) =>
        for key in keys
          @addTranslation(key)

  # @private
  setupTable: ->
    thead = $('<thead/>').appendTo(@table)
    @tbody = $('<tbody/>').appendTo(@table)

    tr = $('<tr/>').addClass('untranslated approved unapproved').appendTo(thead)
    $('<th/>').appendTo tr

    for own locale, data of @locales #when locale isnt @base_locale
      th = $('<th/>').appendTo(tr)
      klass = if data.required
        'text-error'
      else if data.targeted
        'text-info'
      else
        null
      $('<span/>').addClass(klass).text(locale).appendTo th
      th.append ' '
      if data.finished
        $('<i/>').addClass('fa fa-check').appendTo th

  reload: ->
    @scroll.reset()
    @tbody.empty()
    @scroll.loadNextPage()

  # @private
  addTranslation: (key) ->
    tr = $('<tr/>').appendTo(@tbody)
    td = $('<td/>').text(key.original_key).appendTo(tr)
    $('<br/>').appendTo td
    $('<small/>').addClass('muted').text(key.source).appendTo td

    for own locale of @locales #when locale isnt @base_locale
      td = $('<td/>').appendTo(tr)
      translation = (t for t in key.translations when t.locale.rfc5646 == locale)[0]
      if translation && translation.translated
        klass = if translation.approved
          'text-success'
        else if translation.approved == false
          'text-error'
        else
          null
        a = $('<a/>').attr('href', translation.url).addClass(klass).appendTo(td)
        if translation.copy?.match(/^\s*$/)
          a.text "(empty)"
        else
          a.text translation.copy[0..30]
      else if translation
        $('<a/>').attr('href', translation.url).addClass('muted').text("(untranslated)").appendTo(td)

  # Changes the display of the list to render an error message.
  #
  # @param [String, null] message The error message. If `null`, the message is
  #   cleared.
  #
  error: (message) ->
    if message?
      tr = $('<tr>').attr('id', 'error').appendTo(@tbody)
      $('<td/>').attr('colspan', @columns).text(message).appendTo(tr)
    else
      @table.find('#error').remove()
