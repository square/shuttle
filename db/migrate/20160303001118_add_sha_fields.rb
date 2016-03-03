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

class AddShaFields < ActiveRecord::Migration

  def change
    # Add columns
    add_column :articles, :name_sha, :string, limit: 64
    add_column :blobs, :path_sha, :string, limit: 64
    add_column :keys, :key_sha, :string, limit: 64
    add_column :keys, :source_copy_sha, :string, limit: 64
    add_column :sections, :name_sha, :string, limit: 64
    add_column :sections, :source_copy_sha, :string, limit: 64
    add_column :source_glossary_entries, :source_copy_sha, :string, limit: 64

    # Fill in the data
    Article.find_each do |article|
      article.update_columns(name_sha: to_hex(article.name))
    end

    Blob.find_each do |blob|
      blob.update_columns(path_sha: to_hex(blob.path))
    end

    Key.find_each do |key|
      key.update_columns(key_sha: to_hex(key.key), source_copy_sha: to_hex(key.source_copy))
    end

    Section.find_each do |section|
      section.update_columns(name_sha: to_hex(section.name), source_copy_sha: to_hex(section.source_copy))
    end

    SourceGlossaryEntry.find_each do |source_glossary_entry|
      source_glossary_entry.update_columns(source_copy_sha: to_hex(source_glossary_entry.source_copy))
    end

    # Don't allow null
    change_column_null :articles, :name_sha, false
    change_column_null :blobs, :path_sha, false
    change_column_null :keys, :key_sha, false
    change_column_null :keys, :source_copy_sha, false
    change_column_null :sections, :name_sha, false
    change_column_null :sections, :source_copy_sha, false
    change_column_null :source_glossary_entries, :source_copy_sha, false

    # Add indeces
    add_index :articles, :name_sha
    add_index :articles, [:project_id, :name_sha], unique: true
    add_index :blobs, [:project_id, :sha, :path_sha], unique: true
    add_index :keys, :source_copy_sha
    add_index :sections, [:article_id, :name_sha], unique: true
    add_index :sections, :name_sha

    execute <<-SQL
        CREATE UNIQUE INDEX keys_unique_new ON keys (project_id, key_sha, source_copy_sha) WHERE section_id IS NULL;
        CREATE UNIQUE INDEX keys_in_section_unique_new ON keys (section_id, key_sha) WHERE section_id IS NOT NULL;
    SQL

  end

  private

  def to_hex(value)
    Digest::SHA2.hexdigest(value)
  end
end
