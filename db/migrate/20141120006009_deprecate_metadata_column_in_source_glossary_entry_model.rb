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

class DeprecateMetadataColumnInSourceGlossaryEntryModel < ActiveRecord::Migration
  def up
    # Create
    add_column :source_glossary_entries, :source_copy, :text
    add_column :source_glossary_entries, :context,     :text
    add_column :source_glossary_entries, :notes,       :text
    add_column :source_glossary_entries, :due_date,    :date

    # Populate
    text_metadata_columns = %w(source_copy context notes)
    SourceGlossaryEntry.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      new_attr_hsh = {}
      text_metadata_columns.each do |column_name|
        new_attr_hsh[column_name] = metadata[column_name]
      end
      new_attr_hsh['due_date'] = Date.strptime(metadata['due_date'], '%m/%d/%Y') if metadata['due_date']
      obj.update_columns new_attr_hsh
    end

    # Add constraints ( after populate )
    change_column_null :source_glossary_entries, :source_copy, false

    # Remove the metadata column
    remove_column :source_glossary_entries, :metadata
  end
end
