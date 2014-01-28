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

# @private
class root.MemoryDataSource
  constructor: (@records) ->
    @reset()

  fetch: (limit) ->
    promise = new $.Deferred()
    promise.resolve(@records[@_offset...@_offset+limit])
    @_offset = Math.min(@records.length, @_offset+limit)
    return promise

  reset: ->
    @_offset = 0

  rewind: (count=@_offset) ->
    @_offset = Math.max(0, @_offset - count)
