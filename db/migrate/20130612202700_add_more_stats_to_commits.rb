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
