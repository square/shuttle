class AddIsBlockTagToKey < ActiveRecord::Migration
  def change
    add_column :keys, :is_block_tag, :boolean, default: false, null: false
    add_index :keys, :is_block_tag
  end
end
