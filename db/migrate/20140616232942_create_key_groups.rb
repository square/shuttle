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

class CreateKeyGroups < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE key_groups (
        id SERIAL PRIMARY KEY,
        project_id integer NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        key text NOT NULL,
        key_sha_raw bytea NOT NULL,
        source_copy text NOT NULL,
        source_copy_sha_raw bytea NOT NULL,
        description text,
        email character varying(255),
        import_batch_id character varying(255),
        metadata text,
        loading boolean DEFAULT false NOT NULL,
        ready boolean DEFAULT false NOT NULL,
        first_import_requested_at timestamp without time zone,
        last_import_requested_at timestamp without time zone,
        first_import_started_at timestamp without time zone,
        last_import_started_at timestamp without time zone,
        first_import_finished_at timestamp without time zone,
        last_import_finished_at timestamp without time zone,
        first_completed_at timestamp without time zone,
        last_completed_at timestamp without time zone,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      )
    SQL

    execute "CREATE INDEX key_groups_project ON key_groups(project_id)"
    execute "CREATE UNIQUE INDEX key_groups_project_keys_unique ON key_groups(project_id, key_sha_raw)"
  end

  def down
    drop_table :key_groups
  end
end
