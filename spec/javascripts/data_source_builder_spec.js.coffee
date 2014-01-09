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
#= require memory_data_source

describe 'DataSourceBuilder', ->
  @let 'dataSource', -> @builder.build()
  @let 'builder', -> new DataSourceBuilder()

  describe 'with a base', ->
    @let 'baseDataSource', -> new MemoryDataSource(@records)
    @let 'records', -> ['Rose Tyler', 'Martha Jones', 'Amy Pond', 'Rory Pond', 'unknown']

    beforeEach ->
      @builder.base(@baseDataSource)

    describe 'with no modifiers', ->
      it 'simply returns the base', ->
        expect(@dataSource).toBe(@baseDataSource)

    describe 'with filtering', ->
      beforeEach ->
        @builder.filter(yes)

      it 'has filtering', ->
        @dataSource.applyFilter 'ponds', (name) -> (/\sPond$/.test(name))
        expectPromise(@dataSource.fetch(3)).toResolveWith(['Amy Pond', 'Rory Pond'])

      describe 'and with caching', ->
        beforeEach ->
          @builder.cache(yes)

        it 'has caching', ->
          @dataSource.applyFilter 'ponds', (name) -> (/\sPond$/.test(name))
          spyOn(@baseDataSource, 'fetch').andCallThrough()
          expectPromise(@dataSource.fetch(1)).toResolveWith(['Amy Pond'])
          expectPromise(@dataSource.fetch(3)).toResolveWith(['Rory Pond'])
          @dataSource.rewind(1)
          expectPromise(@dataSource.fetch(4)).toResolveWith(['Rory Pond'])
          expect(@baseDataSource.fetch.callCount).toEqual(4)

