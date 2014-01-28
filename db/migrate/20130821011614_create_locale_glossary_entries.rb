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

class CreateLocaleGlossaryEntries < ActiveRecord::Migration

  def up
    execute <<-SQL
      CREATE TABLE locale_glossary_entries (
          id SERIAL PRIMARY KEY,
          translator_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
          reviewer_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
          source_glossary_entry_id INTEGER REFERENCES source_glossary_entries(id) ON DELETE CASCADE,
          metadata TEXT,
          searchable_copy TSVECTOR,
          rfc5646_locale CHARACTER VARYING(15) NOT NULL,
          translated BOOLEAN DEFAULT FALSE NOT NULL,
          approved BOOLEAN,
          created_at TIMESTAMP WITHOUT TIME ZONE,
          updated_at TIMESTAMP WITHOUT TIME ZONE
      )
    SQL
  end

  def down 
    drop_table :locale_glossary_entries
  end

end
