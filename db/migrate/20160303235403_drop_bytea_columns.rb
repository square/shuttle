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

class DropByteaColumns < ActiveRecord::Migration
  def change
    remove_column :articles, :name_sha_raw
    remove_column :blobs, :path_sha_raw
    remove_column :keys, :key_sha_raw
    remove_column :keys, :source_copy_sha_raw
    remove_column :sections, :name_sha_raw
    remove_column :sections, :source_copy_sha_raw
    remove_column :source_glossary_entries, :source_copy_sha_raw
  end
end
