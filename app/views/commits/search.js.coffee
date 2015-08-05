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

$(window).ready ->
  table = $('#translations')
  searchForm = $('#filter-form')
  filterSelect = $('#filter-select')
  localeSelect = $('#locales')

  localeSelect.select2({
    maximumSelectionLength: 4
  })

  filterSelect.select2({
    minimumResultsForSearch: Infinity
  })

  prefillForm = () ->
    if $.isEmptyObject($.url().param())
      searchForm.trigger('reset')
    else
      for own param, val of $.url().param()
        if param == 'locales'
          localeSelect.select2('val', table.data('locales'))
        else if param == 'status'
          filterSelect.select2('val', val)
        else
          searchForm.find("[name=#{param}]").val(val.trim())

  prefillForm()