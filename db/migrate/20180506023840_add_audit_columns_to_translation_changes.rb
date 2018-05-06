class AddAuditColumnsToTranslationChanges < ActiveRecord::Migration
  def change
    add_column :translation_changes, :tm_match, :decimal
    add_column :translation_changes, :sha, :string, limit: 40
    add_column :translation_changes, :role, :string
    add_column :translation_changes, :project_id, :integer
    add_column :translation_changes, :is_edit, :boolean, default: false

    add_index :translation_changes, :project_id
  end
end
