class AddMetadataToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD COLUMN metadata TEXT"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN metadata"
  end
end
