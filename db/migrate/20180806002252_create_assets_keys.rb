class CreateAssetsKeys < ActiveRecord::Migration
  def change
    create_table :assets_keys do |t|
      t.references :asset, index: true, foreign_key: true
      t.references :key, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
