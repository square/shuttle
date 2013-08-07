class MakeCommitsNotReadyByDefault < ActiveRecord::Migration
  def up
    execute "ALTER TABLE ONLY commits ALTER COLUMN ready SET DEFAULT FALSE"
  end

  def down
    execute "ALTER TABLE ONLY commits ALTER COLUMN ready SET DEFAULT TRUE"
  end
end
