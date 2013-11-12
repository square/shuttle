class AddExportedToCommits < ActiveRecord::Migration
  def change
    add_column :commits, :exported, :boolean, default: false, null: false
  end
end
