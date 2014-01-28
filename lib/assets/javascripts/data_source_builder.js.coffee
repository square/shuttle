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

#= require ajax_data_source
#= require filtering_data_source
#= require caching_data_source

root = exports ? this

# @private
class root.DataSourceBuilder
  base: (@_base) -> this
  url: (@_url) -> this
  options: (@_options) -> this
  filter: (@_filter) -> this
  cache: (@_cache) -> this

  build: ->
    if (@_base? and @_url?) or (not @_base? and not @_url?)
      throw new Error("Cannot provide both a base data source and a URL")

    dataSource = @_base or new AjaxDataSource(@_url, @_options)
    dataSource = new CachingDataSource(dataSource) if @_cache
    dataSource = new FilteringDataSource(dataSource) if @_filter
    return dataSource
