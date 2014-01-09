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

#= require data_source_builder

(($) ->

  # Infinite scrolling, jQuery-style.  When the bottom of the page is reached,
  # this element automatically loads new rows and appends them.
  #
  # @param [DataSource, String, Function] dataSource Either a data source to
  #   load new rows from, or a URL (or function that returns a URL) to fetch new
  #   rows from.
  # @param [Object] options Additional options.
  # @option options [Function] renderer The function to execute with new rows.
  #   Passed an array of new rows. (Required.)
  # @option options [Boolean] windowScroll (false) If `true`, the scroll
  #   listener will be attached to the window, not the DOM element.
  # @option options [Object] dataSourceOptions Additional options to pass to the
  #   data source.

  $.fn.infiniteScroll = (dataSource, options={}) ->
    if typeof dataSource in ['string', 'function']
      dataSource = new DataSourceBuilder().
        url(dataSource).
        options(options.dataSourceOptions).
        build()
    new InfiniteScroll($(this), dataSource, options)
)(jQuery)

# @private
class InfiniteScroll
  constructor: (@element, @dataSource, @options={}) ->
    @reset()
    @scroller = (if @options.windowScroll then $(window) else @element)
    @scroller.scroll => @loadNextPage() if @isAtEnd() && @hasMoreRows()
    @loadNextPage()

  reset: ->
    @end_of_scroll = false
    @dataSource.reset()

  # @private
  isAtEnd: ->
    height = if @scroller[0] == window then $(document).height() else @scroller[0].scrollHeight
    @scroller.scrollTop() == height - @scroller.innerHeight()

  # @private
  hasMoreRows: ->
    !@end_of_scroll && !@loading_more?

  # @private
  loadNextPage: ->
    unless @loading_more?
      @loading_more = $('<p/>').addClass('loading-more').text(" Loading more…")
      $('<i/>').addClass('fa fa-spinner spinning').prependTo @loading_more
      if (@scroller[0] == window)
        @loading_more.insertAfter(@element)
      else
        @loading_more.appendTo(@element)

    @loadAndAppend()

  append: (records) ->
    if records.length > 0 then @options.renderer(records) else @end_of_scroll = true
    if @loading_more?
      @loading_more.remove()
      @loading_more = null

  # @private
  loadAndAppend: ->
    @dataSource.fetch(50)
      .then (records) =>
        @append records
      , =>
        new Flash('alert').text("Couldn’t load additional items.");
        
        if @loading_more?
          @loading_more.remove()
          @loading_more = null
        @end_of_scroll = true
