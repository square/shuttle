class AddCompletedAtToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD COLUMN completed_at TIMESTAMP WITHOUT TIME ZONE"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN completed_at"
  end
end
