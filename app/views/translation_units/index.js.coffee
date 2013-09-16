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
  translationUnitsSearchForm = $('#translation-units-search-form')
  table = $('#translation_units')

  sr = new TranslationUnitsSearch(table, table.data('url'))

  makeURL = -> "#{table.data('url')}?#{translationUnitsSearchForm.serialize()}"
  scroll = table.infiniteScroll makeURL,
    windowScroll: true
    renderer: (translation_units) =>
      for translation_unit in translation_units
        do (translation_unit) -> sr.addTranslationUnit(translation_unit)
    dataSourceOptions: {type: 'GET'}

  translationUnitsSearchForm.submit ->
    scroll.reset()
    scroll.loadNextPage()
    false
