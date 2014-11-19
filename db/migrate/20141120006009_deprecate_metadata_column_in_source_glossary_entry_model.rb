class DeprecateMetadataColumnInSourceGlossaryEntryModel < ActiveRecord::Migration
  def up
    # Create
    add_column :source_glossary_entries, :source_copy, :text
    add_column :source_glossary_entries, :context,     :text
    add_column :source_glossary_entries, :notes,       :text
    add_column :source_glossary_entries, :due_date,    :date

    # Populate
    text_metadata_columns = %w(source_copy context notes)
    SourceGlossaryEntry.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      new_attr_hsh = {}
      text_metadata_columns.each do |column_name|
        new_attr_hsh[column_name] = metadata[column_name]
      end
      new_attr_hsh['due_date'] = Date.strptime(metadata['due_date'], '%m/%d/%Y') if metadata['due_date']
      obj.update_columns new_attr_hsh
    end

    # Add constraints ( after populate )
    change_column_null :source_glossary_entries, :source_copy, false

    # Remove the metadata column
    remove_column :source_glossary_entries, :metadata
  end
end
