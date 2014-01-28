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

class RemoveLegacySearchFields < ActiveRecord::Migration
  def up
    execute "ALTER TABLE glossary_entries DROP searchable_copy, DROP searchable_source_copy, DROP source_copy_prefix"
    execute "ALTER TABLE keys DROP searchable_key, DROP key_prefix"
    execute "ALTER TABLE locale_glossary_entries DROP searchable_copy"
    execute "ALTER TABLE source_glossary_entries DROP searchable_source_copy, DROP source_copy_prefix"
    execute "ALTER TABLE translation_units DROP searchable_copy, DROP searchable_source_copy"
    execute "ALTER TABLE translations DROP searchable_copy, DROP searchable_source_copy"
  end

  def down

  end
end
