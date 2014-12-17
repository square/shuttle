class RemoveTranslationUnitsTable < ActiveRecord::Migration
  def change
    drop_table :translation_units
  end
end
