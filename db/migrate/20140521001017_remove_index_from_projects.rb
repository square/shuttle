class RemoveIndexFromProjects < ActiveRecord::Migration
  def up
    execute "DROP INDEX projects_repo;"
  end

  def down
    execute "CREATE UNIQUE INDEX projects_repo ON projects USING btree (lower((repository_url)::text));"
  end
end
