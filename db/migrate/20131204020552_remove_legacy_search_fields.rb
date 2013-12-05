class RemoveLegacySearchFields < ActiveRecord::Migration
  def up
    execute "ALTER TABLE glossary_entries DROP searchable_copy, DROP searchable_source_copy, DROP source_copy_prefix"
    execute "ALTER TABLE keys DROP searchable_key, DROP key_prefix"
    execute "ALTER TABLE locale_glossary_entries DROP searchable_copy"
    execute "ALTER TABLE source_glossary_entries DROP searchable_source_copy, DROP source_copy_prefix"
    execute "ALTER TABLE translation_units DROP searchable_copy, DROP searchable_source_copy"
    execute "ALTER TABLE translations DROP searchable_copy, DROP searchable_source_copy"
  end

  def down

  end
end
