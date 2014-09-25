class RemoveStatsColumnFromCommitsTable < ActiveRecord::Migration
  def change
    remove_column :commits, :stats
  end
end
