class DropNotnullConstraintFromRepositoryUrl < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE projects
        ALTER COLUMN repository_url DROP NOT NULL,
        DROP CONSTRAINT projects_repository_url_check;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE projects
        ALTER COLUMN repository_url SET NOT NULL,
        ADD CONSTRAINT projects_repository_url_check CHECK ((char_length((repository_url)::text) > 0));
    SQL
  end
end
