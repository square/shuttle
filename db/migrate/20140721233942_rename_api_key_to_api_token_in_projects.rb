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

class RenameApiKeyToApiTokenInProjects < ActiveRecord::Migration
  def up
    rename_column :projects, :api_key, :api_token # to make it more clear. `key` is a very overloaded term in Shuttle.

    execute "ALTER TABLE projects DROP CONSTRAINT projects_api_key_key;"
    execute "CREATE UNIQUE INDEX unique_api_token ON projects (api_token);"
  end

  def down
    rename_column :projects, :api_token, :api_key

    execute "ALTER TABLE projects ADD CONSTRAINT projects_api_key_key UNIQUE (api_key);"
    execute "DROP INDEX unique_api_token;"
  end
end
