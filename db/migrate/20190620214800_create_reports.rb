class CreateReports < ActiveRecord::Migration
  def change
    create_table :reports do |t|
      t.datetime :date
      t.string :project
      t.string :locale
      t.integer :strings
      t.integer :words
      t.string :report_type

      t.timestamps null: false
    end
    add_index :reports, :date
  end
end
