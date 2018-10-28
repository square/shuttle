class AddReasonSeverityToTranslationChanges < ActiveRecord::Migration
  def change
    add_column :translation_changes, :reason_severity, :smallint
  end
end
