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

class CreateBlobKeys < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE blobs_keys (
        project_id integer NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        sha_raw bytea NOT NULL,
        key_id INTEGER NOT NULL REFERENCES keys(id) ON DELETE CASCADE,
        FOREIGN KEY (project_id, sha_raw) REFERENCES blobs(project_id, sha_raw) ON DELETE CASCADE,
        PRIMARY KEY (project_id, sha_raw, key_id)
      )
    SQL

    execute "ALTER TABLE blobs ADD keys_cached BOOLEAN NOT NULL DEFAULT FALSE"
  end

  def down
    execute "ALTER TABLE blobs DROP keys_cached"

    drop_table :blobs_keys
  end
end
