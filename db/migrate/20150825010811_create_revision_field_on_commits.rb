# Copyright 2015 Square Inc.
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

class CreateRevisionFieldOnCommits < ActiveRecord::Migration
  def change
    add_column :commits, :revision, :string, limit: 40

    Commit.define_singleton_method(:readonly_attributes) { [] }
    Commit.find_each do |commit|
      commit.update! revision: commit.revision_raw.unpack('H*').first
    end
    change_column_null :commits, :revision, false

    add_index :commits, [:project_id, :revision], unique: true
    remove_column :commits, :revision_raw
  end
end
