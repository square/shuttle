class AddMoreStatsToCommits < ActiveRecord::Migration
  def up
    execute "ALTER TABLE commits ADD COLUMN translations_new INTEGER NOT NULL DEFAULT 0 CHECK (translations_new >= 0)"
    execute "ALTER TABLE commits ADD COLUMN translations_pending INTEGER NOT NULL DEFAULT 0 CHECK (translations_pending >= 0)"
    execute "ALTER TABLE commits ADD COLUMN words_new INTEGER NOT NULL DEFAULT 0 CHECK (words_new >= 0)"
    execute "ALTER TABLE commits ADD COLUMN words_pending INTEGER NOT NULL DEFAULT 0 CHECK (words_pending >= 0)"
  end

  def down
    execute "ALTER TABLE commits DROP COLUMN translations_new"
    execute "ALTER TABLE commits DROP COLUMN translations_pending"
    execute "ALTER TABLE commits DROP COLUMN words_new"
    execute "ALTER TABLE commits DROP COLUMN words_pending"
  end
end
