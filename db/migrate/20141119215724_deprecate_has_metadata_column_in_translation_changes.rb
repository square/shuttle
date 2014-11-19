class DeprecateHasMetadataColumnInTranslationChanges < ActiveRecord::Migration
  def up
    # Create
    add_column :translation_changes, :diff, :text

    # Populate
    TranslationChange.find_each do |obj|
      obj.update_columns diff: JSON.parse(obj.metadata)["diff"]
    end

    # Remove the metadata column
    remove_column :translation_changes, :metadata
  end
end
