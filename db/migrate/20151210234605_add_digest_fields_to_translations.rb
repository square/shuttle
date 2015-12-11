class AddDigestFieldsToTranslations < ActiveRecord::Migration
  def up
    # Translations must have a source_copy to translate
    change_column_null :translations, :source_copy, false
    add_column :translations, :source_copy_sha_raw, :binary

    # Populate the source copy sha for all existing translations
    Translation.all.each do |translation|
      translation.update_attributes!(updated_at: Time.now)
    end

    # Now add the non-null constraint and add an index
    change_column_null :translations, :source_copy_sha_raw, false
    add_index :translations, :source_copy_sha_raw
  end

  def down
    change_column_null :translations, :source_copy, :text, true
    remove_column :translations, :source_copy_sha_raw
  end
end
