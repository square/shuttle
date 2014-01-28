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

require 'ostruct'

Tire.configure do
  url Shuttle::Configuration.elasticsearch.url
end

Tire::Model::Search.index_prefix "shuttle_#{Rails.env}"

# Tire <-> Kaminari compatibility; Kaminari needs to know the human name of the
# model in order to display the page_entries_info block, but since Tire results
# can be heterogeneous, there is no way to do this. So, we assume the first
# result's type is representative of the entire result set.

class Tire::Results::Collection
  def model_name() first ? first.class.model_name : OpenStruct.new(human: 'Record') end
end
