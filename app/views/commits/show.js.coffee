# Copyright 2013 Square Inc.
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

$(window).ready ->
  element = $('#translations')
  baseLocale = element.attr('data-locale')
  filterField = $('#filter-field')

  keyDataSource = new DataSourceBuilder()
    .url(element.attr('data-url'))
    .cache(yes)
    .filter(yes)
    .build()

  keyList = new KeyList(
    element,
    keyDataSource,
    JSON.parse(element.attr('data-locales')),
    baseLocale
  )

  $('#filter-form').submit ->
    keyFilter = filterField.val()
    keyDataSource.applyFilter 'key', (key) ->
      key.original_key.indexOf(keyFilter) > -1
    keyList.reload()
    return false

  $('#filter-select').change ->
    selection = $(this).val()

    switch selection
      when null, ''
        filter = -> true

      when 'untranslated'
        filter = (key) ->
          key.translations.some (t) ->
            t.locale.rfc5646 isnt baseLocale and not t.translated

      when 'unapproved'
        filter = (key) ->
          key.translations.some (t) ->
            t.locale.rfc5646 isnt baseLocale and t.translated and not t.approved

      when 'approved'
        filter = (key) ->
          key.translations.every (t) ->
            t.locale.rfc5646 is baseLocale or t.approved

      else
        throw new Error("unknown filter value '#{selection}'")

    keyDataSource.applyFilter 'state', filter
    keyList.reload()
