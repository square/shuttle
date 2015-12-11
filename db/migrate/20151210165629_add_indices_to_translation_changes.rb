class AddIndicesToTranslationChanges < ActiveRecord::Migration
  def change
    add_index :translation_changes, :translation_id
  end
end
