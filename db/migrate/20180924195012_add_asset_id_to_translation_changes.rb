class AddAssetIdToTranslationChanges < ActiveRecord::Migration
  def change
    add_reference :translation_changes, :asset, index: true, foreign_key: true
  end
end
