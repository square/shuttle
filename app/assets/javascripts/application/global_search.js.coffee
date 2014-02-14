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

# This object manages the search results of the global search page.

class root.GlobalSearch

  # Creates a new search results manager.
  #
  # @param [jQuery element] element A `TABLE` element to store search results
  #   in.
  # @param [String] url A URL to fetch search results from.
  # @param [InfiniteScroll] scroll An infinite scroll manager.

  constructor: (@element, @url, @scroll=null) ->
    this.setupTable()

  # Clears the table and fetches new search results.
  #
  # @param [String] params Query parameters to include with the URL.

  refresh: ->
    this.setupTable()
    @scroll.reset()
    @scroll.loadNextPage()

  # Appends a translation to the results list.
  #
  # @param [Object] translation Translation information.

  addTranslation: (translation) ->
    tr = $('<tr/>').appendTo(@body)
    $('<td/>').text(translation.project.name).appendTo tr
    $('<a>', {
      text: translation.id
      href: translation.url
    }).appendTo( $('<td/>').appendTo tr )
    $('<td/>').text(translation.source_locale.rfc5646).appendTo tr
    $('<td/>').addClass('translation-entry').text(translation.source_copy).appendTo tr
    $('<td/>').text(translation.locale.rfc5646).appendTo tr

    if translation.translated
      class_name = if translation.approved == true
          'text-success'
        else if translation.approved == false
          'text-error'
        else
          'text-info'
      $('<td/>').addClass('translation-entry').addClass(class_name).text(translation.copy).appendTo tr
    else
      $('<td/>').addClass('translation-entry').addClass('muted').text("(untranslated)").appendTo tr

  # Sets or clears a table-wide informational message. Removes all rows from the
  # table.
  #
  # @param [String, null] A message to display, or `null` to clear the message.

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

    $('<th/>').text("Project").appendTo tr
    $('<th/>').text("ID").appendTo tr
    $('<th/>').text("From").appendTo tr
    $('<th/>').text("Source").appendTo tr
    $('<th/>').text("To").appendTo tr
    $('<th/>').text("Translation").appendTo tr
    @body = $('<tbody/>').appendTo(@element)
