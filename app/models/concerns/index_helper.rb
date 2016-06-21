# Copyright 2016 Square Inc.
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


# Include this module in model after including `Elasticsearch::Model`.
# Define INDEX_FIELD array including regular fields that are able to reuse
# rails active record methods to retrieve value from database. Create method
# `special_index_fields` to return a hash including all special fileds

module IndexHelper
  def regular_index_fields
    []
  end

  # override Elasticsearch::Model::Serializing.as_indexed_json method to only include mapped fields
  def as_indexed_json(options={})
    Hash[regular_index_fields.map { |field| [field, self.send(field)] }].merge(special_index_fields)
  end

  def special_index_fields
    {}
  end

  def update_elasticsearch_index
    self.__elasticsearch__.update_document
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def refresh_elasticsearch_index!
      self.__elasticsearch__.refresh_index!
    end
  end
end