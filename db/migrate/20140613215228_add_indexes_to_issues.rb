class AddIndexesToIssues < ActiveRecord::Migration
  def up
    execute "CREATE INDEX issues_translation_status ON issues(translation_id, status)"
    execute "CREATE INDEX issues_translation_status_priority_created_at ON issues(translation_id, status, priority, created_at)"
  end

  def down
    execute "DROP INDEX issues_translation_status"
    execute "DROP INDEX issues_translation_status_priority_created_at"
  end
end
