class RenameLoadingToParsedInBlobs < ActiveRecord::Migration
  def change
    remove_column :blobs, :loading
    add_column    :blobs, :parsed,  :boolean, default: false, null: false
  end
end
