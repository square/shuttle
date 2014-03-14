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

# This object manages the search results of the translation units search page.
#
class root.TranslationUnitsSearch

  # Creates a new search results manager.
  #
  # @param [jQuery element] element A `TABLE` element to store search results
  #   in.
  # @param [String] url A URL to fetch search results from.
  #
  constructor: (@element, @url) ->
    this.setupTable()

  # Clears the table and fetches new search results.
  #
  # @param [String] params Query parameters to include with the URL.
  #
  refresh: (params) ->
    $.ajax @url,
      type: 'GET'
      data: params
      success: (translation_units) =>
        this.setMessage()
        if translation_units.length == 0
          this.setMessage "No translation history found."
        else
          for translation_unit in translation_units
            do (translation_unit) => this.addTranslationUnit(translation_unit)
      error: => this.setMessage("Couldn’t load translation history")

  # Appends a translation unit to the results list.
  #
  # @param [Object] translation_unit Translation information.
  #
  addTranslationUnit: (translation_unit) ->
    tr = $('<tr/>').appendTo(@body)
    src_locale = $('<td/>').text(" " + translation_unit.source_locale.rfc5646).addClass('locale-td').appendTo tr
    $('<img/>').attr('src', translation_unit.source_locale_flag).prependTo src_locale
    $('<td/>').text(translation_unit.source_copy).appendTo tr
    locale = $('<td/>').text(" " + translation_unit.locale.rfc5646).addClass('locale-td').appendTo tr
    $('<img/>').attr('src', translation_unit.locale_flag).prependTo locale
    $('<a>', {
      text: translation_unit.copy
      href: translation_unit.url
    }).appendTo( $('<td/>').appendTo tr )

  # Sets or clears a table-wide informational message. Removes all rows from the
  # table.
  #
  # @param [String, null] A message to display, or `null` to clear the message.
  #
  setMessage: (message=null) ->
    @body.empty()
    if message?
      tr = $('<tr/>').appendTo(@body)
      $('<td/>').attr('colspan', 6).addClass('loading').text(message).appendTo tr

  # @private
  setupTable: ->
    @element.empty()
    thead = $('<thead/>').appendTo(@element)
    tr = $('<tr/>').appendTo(thead)

    $('<th colspan="2"/>').text("Source").appendTo tr
    $('<th colspan="2"/>').text("Target").appendTo tr

    @body = $('<tbody/>').appendTo(@element)
