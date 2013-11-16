class AddIndexesToCommitsKeys < ActiveRecord::Migration
  def up
    execute "CREATE INDEX commits_keys_key_id ON commits_keys(key_id)"
  end

  def down
    execute "DROP INDEX commits_keys_key_id"
  end
end
