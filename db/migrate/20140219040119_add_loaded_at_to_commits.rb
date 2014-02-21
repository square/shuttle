class AddLoadedAtToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD COLUMN loaded_at TIMESTAMP WITHOUT TIME ZONE"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN loaded_at"
  end
end
