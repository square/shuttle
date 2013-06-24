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
  translationSearchForm = $('#translation-search-form')
  table = $('#translations')

  sr = new GlobalSearch(table, table.data('url'))

  makeURL = -> "#{table.data('url')}?#{translationSearchForm.serialize()}"
  scroll = table.infiniteScroll makeURL,
    windowScroll: true
    renderer: (translations) =>
      for translation in translations
        do (translation) -> sr.addTranslation(translation)
    dataSourceOptions: {type: 'GET'}

  translationSearchForm.submit ->
    scroll.reset()
    sr.refresh(translationSearchForm.serialize())
    return false


  element = $('#keys')
  baseLocale = element.attr('data-locale')
  filterField = $('#key-filter-field')

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

  $('#key-search-form').submit ->
    keyFilter = filterField.val()
    keyDataSource.applyFilter 'key', (key) ->
      key.original_key.indexOf(keyFilter) > -1
    keyList.reload()
    return false

  $('#key-filter-select').change ->
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
