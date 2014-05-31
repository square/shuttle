class AddIdToScreenshots < ActiveRecord::Migration
  def up
    execute "ALTER TABLE screenshots ADD COLUMN id SERIAL PRIMARY KEY"
  end

  def down
    execute "ALTER TABLE screenshots DROP COLUMN id"
  end
end
