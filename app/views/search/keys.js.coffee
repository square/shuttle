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
  keyTable = $('#keys')
  keySearchForm = $('#key-search-form')
  makeKeyURL = -> "#{keyTable.data('url')}?#{keySearchForm.serialize()}"

  keyScroll = keyTable.infiniteScroll makeKeyURL,
    windowScroll: true
    renderer: (keys) =>
      for key in keys
        do (key) -> addKey(keyTable, key)

  keySearchForm.submit ->
    keyScroll.reset()
    $.ajax keyTable.data('url'),
      data: keySearchForm.serialize()
      success: (keys) ->
        keyTable.empty()
        header = $('<tr/>').appendTo(keyTable)
        $('<th/>').appendTo header
        for locale_translation in keys[0].translations
          do (locale_translation) ->
            $('<th/>').text(locale_translation.locale.rfc5646).appendTo header

        #TODO this essentially loads the same page twice; we can do better
        keyScroll.loadNextPage(keys)

      error: ->
        $('<div/>').addClass('alert alert-error').text("Couldn't load search results").appendTo($('flashes'))
    false

  addKey = (keyTable, key) ->
    tr = $('<tr/>').appendTo(keyTable)
    keyTD = $('<td/>').text(key.original_key).appendTo(tr)
    $('<br/>').appendTo(keyTD)
    $('<small/>').addClass('muted').text(key.source).appendTo(keyTD)

    for translation in key.translations
      do (translation) ->
        klass = if translation.translated && translation.approved
          'text-success'
        else if translation.translated
          'text-info'
        else if translation.approved == false
          'text-error'
        else
          ''
        td = $('<td/>').appendTo(tr)
        $('<a/>').text(translation.copy[0..30]).attr('href', translation.url).
        addClass(klass).appendTo(td)
