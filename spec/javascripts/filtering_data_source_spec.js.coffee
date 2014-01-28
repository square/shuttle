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

#= require filtering_data_source
#= require memory_data_source

describe 'FilteringDataSource', ->
  @let 'dataSource', -> new FilteringDataSource(@baseDataSource)
  @let 'baseDataSource', -> new MemoryDataSource(@records)
  @let 'records', -> ['Larry', 'Curly', 'Moe']

  describe 'without any filters', ->
    it 'returns the same records returned by the underlying data source', ->
      expectPromise(@dataSource.fetch(2)).toResolveWith(['Larry', 'Curly'])

    it 'returns no more records when there are no more to be had', ->
      @dataSource.fetch(3)
      expectPromise(@dataSource.fetch(3)).toResolveWith([])

    it 'does not rewind past the first record', ->
      @dataSource.fetch(3)
      @dataSource.rewind(1000)
      expectPromise(@dataSource.fetch(3)).toResolveWith(['Larry', 'Curly', 'Moe'])

    it 'fetches the lesser of the given limit and what is available', ->
      expectPromise(@dataSource.fetch(100)).toResolveWith(['Larry', 'Curly', 'Moe'])

  describe 'with a filter', ->
    beforeEach ->
      @dataSource.applyFilter 'short names', (name) -> name.length <= 3

    it 'returns only those records matching the filter', ->
      expectPromise(@dataSource.fetch(3)).toResolveWith(['Moe'])

    it 'fetches multiple times if needed to get enough matching records', ->
      spyOn(@baseDataSource, 'fetch').andCallThrough()
      expectPromise(@dataSource.fetch(1)).toResolveWith(['Moe'])
      expect(@baseDataSource.fetch.callCount).toEqual(3)

    it 'removing the filter rewinds to the beginning', ->
      @dataSource.fetch(2)
      @dataSource.removeFilter 'short names'
      expectPromise(@dataSource.fetch(1)).toResolveWith(['Moe'])

    it 'can rewind a specific number of records', ->
      @dataSource.fetch(1)
      @dataSource.rewind(1)
      expectPromise(@dataSource.fetch(1)).toResolveWith(['Moe'])

    it 'does not rewind past the first record', ->
      @dataSource.fetch(1)
      @dataSource.rewind(1000)
      expectPromise(@dataSource.fetch(1)).toResolveWith(['Moe'])

    describe 'when it would fetch more than it needs from the base data source', ->
      @let 'records', -> ['Moe', 'John', 'Sam', 'Abe']

      it 'fetches multiple times from the base data store', ->
        spyOn(@baseDataSource, 'fetch').andCallThrough()
        expectPromise(@dataSource.fetch(2)).toResolveWith(['Moe', 'Sam'])
        expect(@baseDataSource.fetch.callCount).toEqual(2)

      it 'rewinds to the appropriate offset after having fetched too many', ->
        spyOn(@dataSource, 'rewind').andCallThrough()
        @dataSource.fetch(2)
        expectPromise(@dataSource.fetch(1)).toResolveWith(['Abe'])
        runs => expect(@dataSource.rewind).toHaveBeenCalledWith(1)
