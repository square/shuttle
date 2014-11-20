class DeprecateHasMetadataColumnInKeyGroups < ActiveRecord::Migration
  def up
    # Create
    add_column :key_groups, :base_rfc5646_locale,      :string
    add_column :key_groups, :targeted_rfc5646_locales, :text

    # KeyGroups are not used yet. No need to migrate any data.

    # Remove the metadata column
    remove_column :key_groups, :metadata
  end
end
