class ChangeCompletedAtToApprovedAt < ActiveRecord::Migration
  def change
    rename_column :commits, :completed_at, :approved_at
  end
end
