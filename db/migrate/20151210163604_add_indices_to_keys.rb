class AddIndicesToKeys < ActiveRecord::Migration
  def change
    add_index :keys, :ready
    add_index :keys, :source_copy_sha_raw
  end
end
