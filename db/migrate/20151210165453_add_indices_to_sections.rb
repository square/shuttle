class AddIndicesToSections < ActiveRecord::Migration
  def change
    add_index :sections, :name_sha_raw
  end
end
