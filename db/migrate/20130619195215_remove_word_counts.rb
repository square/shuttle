# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

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

    Commit.find_each { |c| CommitRecalculator.new.perform(c.id) }
  end
end
