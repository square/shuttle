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
  table = $('#translations')
  searchForm = $('#filter-form')
  makeURL = -> "#{table.data('url')}?#{searchForm.serialize()}"
  localeOrder = table.data('locales').split(',')

  addKey = (key) ->
    tr = $('<tr/>').appendTo(table)
    td = $('<td/>').text(key.original_key).appendTo(tr)
    $('<br/>').appendTo td
    $('<small/>').addClass('muted').text(key.source).appendTo td

    for locale in localeOrder
      do (locale) ->
        translation = (t for t in key.translations when t.locale.rfc5646 == locale)[0]

        if translation?
          klass = if translation.approved
            'text-success'
          else if translation.approved == false
            'text-error'
          else if translation.translated
            'text-info'
          else
            'muted'

          copy = if translation.translated == false
            "(not yet translated)"
          else if /\A\s*\z/.test(translation.copy)
            "(blank string)"
          else
            translation.copy[0..30]

          td = $('<td/>').appendTo(tr)
          $('<a/>').attr('href', translation.url).addClass(klass).
          text(copy).appendTo(td)
        else
          $('<td/>').appendTo tr

  scroll = table.infiniteScroll makeURL,
    windowScroll: true
    renderer: (keys) =>
      for key in keys
        do (key) -> addKey(key)

  searchForm.submit ->
    table.find('tbody').empty()
    scroll.reset()
    scroll.loadNextPage()
#    $.ajax table.data('url'),
#      data: searchForm.serialize()
#      success: (keys) ->
#        for key in keys
#          do (key) -> addKey(key)
#      error: ->
#        $('<div/>').addClass('alert alert-error').text("Couldn't load search results").insertBefore table
    false
