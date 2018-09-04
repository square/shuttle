class CreateAssets < ActiveRecord::Migration
  def change
    create_table :assets do |t|
      t.string :name, null: false
      t.references :project, index: true, null: false
      t.references :user, index: true, null: false
      t.string :base_rfc5646_locale, null: false
      t.text :targeted_rfc5646_locales, null: false
      t.text :description
      t.string :email
      t.integer :priority
      t.datetime :due_date
      t.boolean :ready, null: false, default: false
      t.boolean :loading, null: false, default: false
      t.datetime :approved_at
      t.boolean :hidden, null: false, default: false
      t.string :file_name, null: false
      t.string :import_batch_id
      t.attachment :file
      t.timestamps null: false
    end
  end
end
