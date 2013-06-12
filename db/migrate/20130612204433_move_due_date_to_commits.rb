class MoveDueDateToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD COLUMN due_date DATE"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN due_date"
  end
end
