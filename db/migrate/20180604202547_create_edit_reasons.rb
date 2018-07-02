class CreateEditReasons < ActiveRecord::Migration
  def change
    create_table :edit_reasons do |t|
      t.references :reason, index: true, foreign_key: true
      t.references :translation_change, index: true, foreign_key: true
    end
  end
end
