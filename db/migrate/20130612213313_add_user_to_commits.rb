class AddUserToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD user_id INTEGER REFERENCES users(id) ON DELETE SET NULL"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN user_id"
  end
end
