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

class DropKeyGroupsAndRelatedFields < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE keys
          DROP COLUMN key_group_id,
          DROP COLUMN index_in_key_group,
          ADD COLUMN section_id integer REFERENCES sections(id),
          ADD COLUMN index_in_section integer,
          ADD CONSTRAINT non_negative_index_in_section CHECK ((index_in_section >= 0));

          CREATE UNIQUE INDEX keys_unique ON keys (project_id, key_sha_raw, source_copy_sha_raw) WHERE section_id IS NULL;
          CREATE UNIQUE INDEX keys_in_section_unique ON keys (section_id, key_sha_raw) WHERE section_id IS NOT NULL;
          CREATE UNIQUE INDEX index_in_section_unique ON keys (section_id, index_in_section) WHERE section_id IS NOT NULL AND index_in_section is NOT NULL;
    SQL

    drop_table :key_groups
  end
end
