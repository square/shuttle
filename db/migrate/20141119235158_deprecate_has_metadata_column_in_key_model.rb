class DeprecateHasMetadataColumnInKeyModel < ActiveRecord::Migration
  def up
    # Create
    add_column :keys, :key,          :text
    add_column :keys, :original_key, :text
    add_column :keys, :source_copy,  :text
    add_column :keys, :context,      :text
    add_column :keys, :importer,     :string
    add_column :keys, :source,       :text
    add_column :keys, :fencers,      :text
    add_column :keys, :other_data,   :text

    # Populate
    metadata_columns = %w(key original_key source_copy context importer source fencers other_data)

    readonly_attrs = Key.readonly_attributes
    Key.instance_exec {self._attr_readonly = []}

    Key.find_each do |obj|
      metadata = JSON.parse(obj.metadata)
      new_attr_hsh = {}
      metadata_columns.each do |column_name|
        new_attr_hsh[column_name] = metadata[column_name]
      end
      obj.update_columns new_attr_hsh
    end

    Key.attr_readonly(*readonly_attrs)
    change_column_null :keys, :key, false
    change_column_null :keys, :original_key, false

    # Remove the metadata column
    remove_column :keys, :metadata
  end
end
