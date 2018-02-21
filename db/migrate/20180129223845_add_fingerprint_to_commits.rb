class AddFingerprintToCommits < ActiveRecord::Migration
  def change
    add_column :commits, :fingerprint, :string
    add_column :commits, :duplicate, :boolean, default: false
    add_index :commits, :fingerprint
  end
end
