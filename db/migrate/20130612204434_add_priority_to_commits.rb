class AddPriorityToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD COLUMN priority INTEGER CHECK (priority >= 0 AND priority <= 3)"
    execute "CREATE INDEX commits_priority ON commits(priority, due_date)"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN priority"
  end
end
