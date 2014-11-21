class DeprecateMetadataColumnInLocaleGlossaryEntryModel < ActiveRecord::Migration
  def up
    # Create
    add_column :locale_glossary_entries, :copy,  :text
    add_column :locale_glossary_entries, :notes, :text

    # Populate
    metadata_columns = %w(copy notes)
    LocaleGlossaryEntry.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      hsh = {}
      metadata_columns.each do |column_name|
        hsh[column_name] = metadata[column_name]
      end
      obj.update_columns hsh
    end

    # Remove the metadata column
    remove_column :locale_glossary_entries, :metadata
  end
end
