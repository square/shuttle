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

class CreateShaFieldOnBlobs < ActiveRecord::Migration
  def change
    add_column :blobs, :sha, :string, limit: 40

    Blob.define_singleton_method(:readonly_attributes) { [] }
    Blob.find_each do |blob|
      blob.update! sha: blob.sha_raw.unpack('H*').first
    end
    change_column_null :blobs, :sha, false

    add_index :blobs, [:project_id, :sha, :path_sha_raw], unique: true

    remove_column :blobs, :sha_raw
  end
end
