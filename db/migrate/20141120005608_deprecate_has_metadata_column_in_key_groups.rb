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

class DeprecateHasMetadataColumnInKeyGroups < ActiveRecord::Migration
  def up
    # Create
    add_column :key_groups, :base_rfc5646_locale,      :string
    add_column :key_groups, :targeted_rfc5646_locales, :text

    # KeyGroups are not used yet. No need to migrate any data.

    # Remove the metadata column
    remove_column :key_groups, :metadata
  end
end
