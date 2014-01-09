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

# Provides a data source for fetching records filtered by arbitrary criteria.
# It maintains its own offset, so you simply use #fetch to request more
# records matching the applied filters.
#
class root.FilteringDataSource

  # Builds a new filtering data source with a base data source.
  #
  # @param [Object<#fetch(Number)>] baseDataSource An underlying data source to
  #   pull unfiltered data from.
  constructor: (@baseDataSource) ->
    @reset()

  # Fetches up to `limit` records from the server relative to the current
  # offset. Fewer than `limit` may be retrieved if there are no more records
  # matching the applied filters.
  #
  # @param [Number] limit A positive number of records to fetch.
  # @return [Promise] Returns a Promise that will resolve to the fetched
  #   records or will be rejected with whatever error happens while
  #   requesting records from the server.
  #
  fetch: (limit) ->
    promise = new $.Deferred()
    result  = []
    filters = (filter for own _, filter of @_filters)

    fetchMore = =>
      @baseDataSource.fetch(limit)
        .then (unfiltered) =>
          done = unfiltered.length is 0

          for item in unfiltered
            if filters.every((filter) -> filter(item))
              result.push item
              @_filterIndex.keep()
            else
              @_filterIndex.skip()

          done ||= result.length >= limit

          if done
            @_offset += result.length
            if result.length > limit
              @rewind result.length - limit
            promise.resolve(result[0...limit])
          else
            fetchMore()
        , (args...) ->
          promise.reject(args...)

    fetchMore()

    return promise

  # Applies a filter by name to the fetched data. This function resets the
  # current offset and replaces any previous filter by the same name.
  #
  # @param [String] name A name for the filter, must be unique among filters.
  # @param [Function(Object)] filter A function returning true if the given
  #   object should be included in the result, false otherwise.
  #
  applyFilter: (name, filter) ->
    @rewind()
    @_filters[name] = filter

  # Removes a currently applied filter by name. Resets the current offset.
  #
  # @param [String] name The name of the filter to remove.
  #
  removeFilter: (name) ->
    @rewind()
    delete @_filters[name]

  # Clears all existing filters and resets the underlying data source.
  #
  reset: ->
    @_filters = {}
    @_offset = 0
    @_filterIndex = new FilterIndex()
    @baseDataSource.reset()

  # Rewinds the current offset.
  #
  # @param [Number] count An optional number of records to rewind. If omitted,
  #   then this will rewind back to 0.
  rewind: (count=@_offset) ->
    baseCount = @_filterIndex.rewind(count)
    @baseDataSource.rewind(baseCount)

  _getURL: ->
    if typeof @url is 'function' then @url() else @url


class FilterIndex
  constructor: ->
    @_index = []
    @_offset = 0

  skip: ->
    @_index[@_offset++] = no

  keep: ->
    @_index[@_offset++] = yes

  rewind: (count) ->
    originalOffset = @_offset
    while @_offset > 0 and count > 0
      count-- if @_index[--@_offset]
    originalOffset - @_offset
