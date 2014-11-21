class DropMetadataFieldFromBlobs < ActiveRecord::Migration
  def up
    remove_column :blobs, :metadata
  end

  def down
    add_column :blobs, :metadata, :text
  end
end
