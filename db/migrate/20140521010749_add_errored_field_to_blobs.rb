class AddErroredFieldToBlobs < ActiveRecord::Migration
  def change
    add_column :blobs, :errored, :boolean, default: false, null: false
    add_index :blobs, [:project_id, :sha_raw, :errored]
  end
end
