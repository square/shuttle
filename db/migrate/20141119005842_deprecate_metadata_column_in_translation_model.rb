class DeprecateMetadataColumnInTranslationModel < ActiveRecord::Migration
  def up
    add_column :translations, :source_copy, :text
    add_column :translations, :copy, :text
    add_column :translations, :notes, :text

    # Populate temporary columns
    metadata_columns = %w(source_copy copy notes)

    Translation.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      hsh = {}
      metadata_columns.each do |column_name|
        hsh[:"#{column_name}"] = metadata[column_name]
      end
      obj.update_columns hsh
    end

    # Remove the metadata column
    remove_column :translations, :metadata
  end
end
