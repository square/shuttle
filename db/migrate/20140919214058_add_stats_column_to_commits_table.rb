class AddStatsColumnToCommitsTable < ActiveRecord::Migration
  def change
    add_column :commits, :stats, :text
  end
end
