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

class DeprecateHasMetadataColumnInDailyMetrics < ActiveRecord::Migration
  def up
    # Create
    add_column :daily_metrics, :num_commits_loaded,                :integer
    add_column :daily_metrics, :num_commits_loaded_per_project,    :text
    add_column :daily_metrics, :avg_load_time,                     :float
    add_column :daily_metrics, :avg_load_time_per_project,         :text
    add_column :daily_metrics, :num_commits_completed,             :integer
    add_column :daily_metrics, :num_commits_completed_per_project, :text
    add_column :daily_metrics, :num_words_created,                 :integer
    add_column :daily_metrics, :num_words_created_per_language,    :text
    add_column :daily_metrics, :num_words_completed,               :integer
    add_column :daily_metrics, :num_words_completed_per_language,  :text

    # Populate
    metadata_columns = %w(num_commits_loaded num_commits_loaded_per_project
                           avg_load_time avg_load_time_per_project
                           num_commits_completed num_commits_completed_per_project
                           num_words_created num_words_created_per_language
                           num_words_completed num_words_completed_per_language)

    DailyMetric.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      new_attr_hsh = {}
      metadata_columns.each do |column_name|
        new_attr_hsh[column_name] = metadata[column_name]
      end
      obj.update_columns new_attr_hsh
    end

    # Remove the metadata column
    remove_column :daily_metrics, :metadata
  end
end
