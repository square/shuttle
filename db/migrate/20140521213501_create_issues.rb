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

class CreateIssues < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE issues (
          id SERIAL PRIMARY KEY,
          user_id integer REFERENCES users(id) ON DELETE SET NULL,
          updater_id integer REFERENCES users(id) ON DELETE SET NULL,
          translation_id integer NOT NULL REFERENCES translations(id) ON DELETE CASCADE,
          summary character varying(255),
          description text,
          priority integer,
          kind integer,
          status integer,
          created_at timestamp without time zone,
          updated_at timestamp without time zone
      )
    SQL

    execute "CREATE INDEX issues_user ON issues USING btree (user_id)"
    execute "CREATE INDEX issues_updater ON issues USING btree (updater_id)"
    execute "CREATE INDEX issues_translation ON issues USING btree (translation_id)"
  end

  def down
    drop_table :issues
  end
end
