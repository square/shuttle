class RenameBlobKeysCachedToLoading < ActiveRecord::Migration
  def up
    execute "ALTER TABLE blobs RENAME keys_cached TO loading"
    execute "ALTER TABLE blobs ALTER loading SET DEFAULT true"

    Blob.reset_column_information
    Blob.update_all loading: true
  end

  def down
    execute "ALTER TABLE blobs RENAME loading TO keys_cached"
    execute "ALTER TABLE blobs ALTER keys_cached SET DEFAULT false"

    Blob.reset_column_information
    Blob.update_all keys_cached: false
  end
end
