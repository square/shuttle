class RemoveWordCounts < ActiveRecord::Migration
  def up
    remove_column :commits, :translations_new
    remove_column :commits, :translations_pending
    remove_column :commits, :translations_done
    remove_column :commits, :translations_total
    remove_column :commits, :words_new
    remove_column :commits, :words_pending
    remove_column :commits, :strings_total
  end

  def down
    execute "ALTER TABLE commits ADD COLUMN translations_new integer DEFAULT 0 NOT NULL CHECK ((translations_new >= 0))"
    execute "ALTER TABLE commits ADD COLUMN translations_pending integer DEFAULT 0 NOT NULL CHECK ((translations_pending >= 0))"
    execute "ALTER TABLE commits ADD COLUMN translations_done integer DEFAULT 0 NOT NULL CHECK (translations_done >= 0)"
    execute "ALTER TABLE commits ADD COLUMN translations_total integer DEFAULT 0 NOT NULL CHECK (translations_total >= 0)"
    execute "ALTER TABLE commits ADD COLUMN words_new integer DEFAULT 0 NOT NULL CHECK ((words_new >= 0))"
    execute "ALTER TABLE commits ADD COLUMN words_pending integer DEFAULT 0 NOT NULL CHECK ((words_pending >= 0))"
    execute "ALTER TABLE commits ADD COLUMN strings_total integer DEFAULT 0 NOT NULL CHECK (strings_total >= 0)"

    Commit.find_each { |c| CommitStatsRecalculator.new.perform(c.id) }
  end
end
