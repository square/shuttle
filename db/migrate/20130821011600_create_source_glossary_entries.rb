# Copyright 2013 Square Inc.
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

class CreateSourceGlossaryEntries < ActiveRecord::Migration

  def up
    execute <<-SQL
      CREATE TABLE source_glossary_entries (
          id SERIAL PRIMARY KEY,
          metadata text,
          searchable_source_copy tsvector,
          source_rfc5646_locale character varying(15) NOT NULL,
          source_copy_sha_raw bytea,
          created_at timestamp without time zone,
          updated_at timestamp without time zone,
          source_copy_prefix character(5) NOT NULL
      )
    SQL
  end

  def down 
    drop_table :source_glossary_entries
  end

end
