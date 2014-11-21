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

class DeprecateHasMetadataColumnInKeyModel < ActiveRecord::Migration
  def up
    # Create
    add_column :keys, :key,          :text
    add_column :keys, :original_key, :text
    add_column :keys, :source_copy,  :text
    add_column :keys, :context,      :text
    add_column :keys, :importer,     :string
    add_column :keys, :source,       :text
    add_column :keys, :fencers,      :text
    add_column :keys, :other_data,   :text

    # Populate
    metadata_columns = %w(key original_key source_copy context importer source fencers other_data)

    readonly_attrs = Key.readonly_attributes
    Key.instance_exec {self._attr_readonly = []}

    Key.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      new_attr_hsh = {}
      metadata_columns.each do |column_name|
        new_attr_hsh[column_name] = metadata[column_name]
      end
      obj.update_columns new_attr_hsh
    end

    Key.attr_readonly(*readonly_attrs)
    change_column_null :keys, :key, false
    change_column_null :keys, :original_key, false

    # Remove the metadata column
    remove_column :keys, :metadata
  end
end
