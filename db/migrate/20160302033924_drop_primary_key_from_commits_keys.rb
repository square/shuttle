class DropPrimaryKeyFromCommitsKeys < ActiveRecord::Migration
  def change
    execute <<-SQL
      ALTER TABLE commits_keys DROP CONSTRAINT commits_keys_pkey;
    SQL

    add_index :commits_keys, [:commit_id, :key_id], unique: true
  end
end
