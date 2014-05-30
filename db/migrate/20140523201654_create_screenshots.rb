class CreateScreenshots < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE screenshots(
        commit_id INTEGER NOT NULL REFERENCES commits(id) ON DELETE CASCADE,
        created_at timestamp without time zone,
        updated_at timestamp without time zone
      )
    SQL
  end

  def down
    drop_table :screenshots
  end
end
