class CreateTranslationChanges < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE translation_changes (
        id SERIAL PRIMARY KEY,
        translation_id integer NOT NULL REFERENCES translations(id) ON DELETE CASCADE,
        metadata text,
        created_at timestamp without time zone,
        user_id integer REFERENCES users(id) ON DELETE SET NULL
      )
    SQL
  end
  def down
    drop_table :translation_changes
  end
end
