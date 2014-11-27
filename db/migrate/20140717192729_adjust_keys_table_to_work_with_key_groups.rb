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

class AdjustKeysTableToWorkWithKeyGroups < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE keys
          ADD COLUMN key_group_id integer REFERENCES key_groups(id),
          ADD COLUMN index_in_key_group integer,
          ADD CONSTRAINT non_negative_index_in_key_group CHECK ((index_in_key_group >= 0));
    SQL

    execute "DROP INDEX keys_unique;"
    execute "CREATE UNIQUE INDEX keys_unique ON keys (project_id, key_sha_raw, source_copy_sha_raw) WHERE key_group_id IS NULL;"
    execute "CREATE UNIQUE INDEX keys_in_key_group_unique ON keys (key_group_id, key_sha_raw) WHERE key_group_id IS NOT NULL;"
    execute "CREATE UNIQUE INDEX index_in_key_group_unique ON keys (key_group_id, index_in_key_group) WHERE key_group_id IS NOT NULL AND index_in_key_group is NOT NULL;"
  end

  def down
    execute "DROP INDEX keys_unique;"
    execute "CREATE UNIQUE INDEX keys_unique ON keys USING btree (project_id, key_sha_raw, source_copy_sha_raw);"
    execute "DROP INDEX keys_in_key_group_unique;"
    execute "DROP INDEX index_in_key_group_unique;"

    drop_column :keys, :key_group_id
    drop_column :keys, :index_in_key_group
  end
end
