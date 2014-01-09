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

#= require caching_data_source

describe 'CachingDataSource', ->
  @let 'dataSource', -> new CachingDataSource(@baseDataSource)
  @let 'baseDataSource', -> new LazyDataSource (offset) -> offset

  it 'caches fetched records', ->
    spyOn(@baseDataSource, 'fetch').andCallThrough()
    @dataSource.fetch(1)
    @dataSource.rewind(1)
    @dataSource.fetch(1)
    expect(@baseDataSource.fetch.callCount).toEqual(1)

  it 'retrieves records from the base data source', ->
    expectPromise(@dataSource.fetch(3)).toResolveWith([0, 1, 2])

  it 'can reset the cache', ->
    spyOn(@baseDataSource, 'fetch').andCallThrough()
    @dataSource.fetch(1)
    @dataSource.reset()
    @dataSource.fetch(1)
    expect(@baseDataSource.fetch.callCount).toEqual(2)

  it 'does not rewind past the beginning', ->
    @dataSource.rewind(5)
    expectPromise(@dataSource.fetch(3)).toResolveWith([0, 1, 2])

  describe 'with a base data source with finite size', ->
    @let 'baseDataSource', -> new MemoryDataSource([5, 6, 7])

    it 'does not fetch any more records from the base once it reaches the end', ->
      spyOn(@baseDataSource, 'fetch').andCallThrough()
      @dataSource.fetch(4)
      @dataSource.rewind()
      expectPromise(@dataSource.fetch(100)).toResolveWith([5, 6, 7])
      expect(@baseDataSource.fetch.callCount).toEqual(1)
