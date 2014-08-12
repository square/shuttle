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
