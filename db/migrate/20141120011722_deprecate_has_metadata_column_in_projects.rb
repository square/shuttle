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

class DeprecateHasMetadataColumnInProjects < ActiveRecord::Migration
  def up
    # Create
    add_column :projects, :base_rfc5646_locale,      :string, default: 'en'
    add_column :projects, :targeted_rfc5646_locales, :text
    add_column :projects, :skip_imports,             :text
    add_column :projects, :key_exclusions,           :text
    add_column :projects, :key_inclusions,           :text
    add_column :projects, :key_locale_exclusions,    :text
    add_column :projects, :key_locale_inclusions,    :text
    add_column :projects, :skip_paths,               :text
    add_column :projects, :only_paths,               :text
    add_column :projects, :skip_importer_paths,      :text
    add_column :projects, :only_importer_paths,      :text
    add_column :projects, :default_manifest_format,  :string
    add_column :projects, :watched_branches,         :text
    add_column :projects, :touchdown_branch,         :string
    add_column :projects, :manifest_directory,       :text
    add_column :projects, :manifest_filename,        :string
    add_column :projects, :github_webhook_url,       :text
    add_column :projects, :stash_webhook_url,        :text

    # Populate
    metadata_columns = %w(base_rfc5646_locale targeted_rfc5646_locales skip_imports key_exclusions key_inclusions
                          key_locale_exclusions key_locale_inclusions skip_paths only_paths skip_importer_paths
                          only_importer_paths default_manifest_format watched_branches touchdown_branch
                          manifest_directory manifest_filename github_webhook_url stash_webhook_url)

    Project.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      new_attr_hsh = {}
      metadata_columns.each do |column_name|
        new_attr_hsh[column_name] = metadata[column_name]
      end
      obj.update_columns new_attr_hsh
    end

    change_column_null :projects, :base_rfc5646_locale, false

    # Remove the metadata column
    remove_column :projects, :metadata
  end
end
