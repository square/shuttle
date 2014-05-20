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

class CreateComments < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE comments (
          id SERIAL PRIMARY KEY,
          user_id integer REFERENCES users(id) ON DELETE SET NULL,
          issue_id integer NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
          content text,
          created_at timestamp without time zone,
          updated_at timestamp without time zone
      )
    SQL

    execute "CREATE INDEX comments_user ON comments USING btree (user_id)"
    execute "CREATE INDEX comments_issue ON comments USING btree (issue_id)"
  end

  def down
    drop_table :comments
  end
end
