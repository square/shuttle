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

class DeprecateMetadataColumnInCommits < ActiveRecord::Migration
  def up
    # Create
    add_column :commits, :description,      :text
    add_column :commits, :author,           :string
    add_column :commits, :author_email,     :string
    add_column :commits, :pull_request_url, :text
    add_column :commits, :import_batch_id,  :string
    add_column :commits, :import_errors,    :text

    # Populate
    text_metadata_columns = %w(description author author_email pull_request_url import_batch_id import_errors)
    Commit.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      new_attr_hsh = {}
      text_metadata_columns.each do |column_name|
        new_attr_hsh[column_name] = metadata[column_name]
      end
      obj.update_columns new_attr_hsh
    end

    # Remove the metadata column
    remove_column :commits, :metadata
  end
end
