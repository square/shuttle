class AddCreatedAtToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD COLUMN created_at TIMESTAMP WITHOUT TIME ZONE"
    execute "UPDATE commits SET created_at = CURRENT_TIME"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN created_at"
  end
end
