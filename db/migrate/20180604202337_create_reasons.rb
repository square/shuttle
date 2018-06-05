class CreateReasons < ActiveRecord::Migration
  def change
    create_table :reasons do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.string :description

      t.timestamps
    end
  end
end
