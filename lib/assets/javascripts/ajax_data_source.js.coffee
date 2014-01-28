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

# Provides a data source for fetching records using XMLHttpRequest. It
# maintains its own offset, so you simply use #fetch to request more records.
#
class root.AjaxDataSource

  # Builds a new data source with a base URL.
  #
  # @param [String|Function] url A URL (or builder) that accepts `offset` and
  #   `limit` query string parameters and returns a JSON array of data.
  # @param [Object] options Additional options to pass to `jQuery.ajax`.
  constructor: (@url, @options={}) ->
    @reset()

  # Fetches up to `limit` records from the server relative to the current
  # offset. Fewer than `limit` may be retrieved if there are fewer than `limit`
  # records left after the current offset.
  #
  # @param [Number] limit A positive number of records to fetch.
  # @return [Promise] Returns a Promise that will resolve to the fetched
  #   records or will be rejected with whatever error happens while
  #   requesting records from the server.
  #
  fetch: (limit) ->
    promise = new $.Deferred()

    $.ajax(@_getURL(), $.extend({}, @options, data: {offset: @_offset, limit}))
      .then (result) =>
        @_offset += result.length
        promise.resolve(result)
      , (args...) ->
        promise.reject(args...)

    return promise

  # Resets the state of this data source to start back at the beginning.
  #
  reset: ->
    @_offset = 0

  # Rewinds the current offset.
  #
  # @param [Number] count An optional number of records to rewind. If omitted,
  #   then this will rewind back to 0.
  rewind: (count=@_offset) ->
    @_offset = Math.max(0, @_offset - count)

  _getURL: ->
    if typeof @url is 'function' then @url() else @url
