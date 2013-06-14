class OrderProjectsByName < ActiveRecord::Migration
  def up
    execute "CREATE INDEX projects_name ON projects(LOWER(name))"
  end

  def down
    execute "DROP INDEX projects_name"
  end
end
