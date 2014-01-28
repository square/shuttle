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

#= require memory_data_source

describe 'MemoryDataSource', ->
  @let 'dataSource', -> new MemoryDataSource(@records)
  @let 'records', -> ['a', 'b', 'c']

  describe '#fetch', ->
    it 'returns a promise', ->
      expect(typeof @dataSource.fetch(100).then).toEqual('function')

    it 'yields "limit" records if there are at least that many', ->
      expectPromise(@dataSource.fetch(1)).toResolveWith(['a'])

    it 'yields fewer than "limit" records if there are not enough', ->
      expectPromise(@dataSource.fetch(1000)).toResolveWith(['a', 'b', 'c'])

  describe '#rewind', ->
    it 'cannot rewind past the beginning', ->
      @dataSource.rewind(1000)
      expectPromise(@dataSource.fetch(1)).toResolveWith(['a'])

    it 'can rewind to somewhere other than the beginning', ->
      @dataSource.fetch(2)
      @dataSource.rewind(1)
      expectPromise(@dataSource.fetch(1)).toResolveWith(['b'])

  describe '#reset', ->
    it 'rewinds to the beginning', ->
      @dataSource.fetch(3)
      @dataSource.reset()
      expectPromise(@dataSource.fetch(1)).toResolveWith(['a'])
