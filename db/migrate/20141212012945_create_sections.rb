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

class CreateSections < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE sections (
        id SERIAL PRIMARY KEY,
        article_id integer NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
        name text NOT NULL,
        name_sha_raw bytea NOT NULL,
        source_copy text NOT NULL,
        source_copy_sha_raw bytea NOT NULL,
        active boolean DEFAULT true NOT NULL,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      )
    SQL

    add_index(:sections, [:article_id])
    add_index(:sections, [:article_id, :name_sha_raw], unique: true)
  end

  def down
    drop_table :sections
  end
end
