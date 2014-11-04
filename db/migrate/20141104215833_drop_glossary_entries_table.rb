class DropGlossaryEntriesTable < ActiveRecord::Migration
  def up
    drop_table :glossary_entries
  end

  def down
    raise 'Not Implemented'
  end
end
