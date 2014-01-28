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

# Provides a data source for fetching records with in-memory caching. It
# maintains its own offset, so you simply use #fetch to request more records.
#
class root.CachingDataSource

  # Builds a new caching data source with a base data source.
  #
  # @param [Object<#fetch(Number)>] baseDataSource An underlying data source to
  #   pull data from.
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

    if @_cache.length >= @_offset+limit
      # we have everything cached
      promise.resolve @_cache[@_offset...@_offset+limit]
      @_offset += limit
    else
      # we might not have everything cached
      if @_count?
        # we have everything we can get
        promise.resolve @_cache[@_offset...@_count]
        @_offset = @_count
      else
        # we haven't hit the end yet, get more
        @baseDataSource.fetch(limit)
          .then (result) =>
            @_cache.push result...
            @_count = @_cache.length if result.length < limit
            @fetch(limit).then (result) ->
              promise.resolve(result)
          , (args...) ->
            promise.reject(args...)

    return promise

  # Clears all existing filters and resets the underlying data source.
  #
  reset: ->
    @_cache  = []
    @_offset = 0
    @_count  = null
    @baseDataSource.reset()

  # Rewinds the current offset.
  #
  # @param [Number] count An optional number of records to rewind. If omitted,
  #   then this will rewind back to 0.
  rewind: (count=@_offset) ->
    @_offset = Math.max(0, @_offset - count)
