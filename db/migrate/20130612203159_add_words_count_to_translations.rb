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

class AddWordsCountToTranslations < ActiveRecord::Migration
  def up
    execute "ALTER TABLE translations ADD COLUMN words_count INTEGER DEFAULT 0"

    say_with_time "Updating translations..." do
      Translation.find_each do |t|
        t.send :count_words
        t.save!
      end
    end

    execute "ALTER TABLE translations ALTER words_count SET NOT NULL"
  end

  def down
    execute "ALTER TABLE translations DROP COLUMN words_count"
  end
end
