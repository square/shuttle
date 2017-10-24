class AddCreatedAtToCommitsKeys < ActiveRecord::Migration
  def change
    add_column :commits_keys, :created_at, :datetime
  end
end
