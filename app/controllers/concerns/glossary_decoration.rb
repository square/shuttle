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

# Mixin that adds a `decorate` method that adds additional information to
# Translation JSON serializations.

module GlossaryDecoration
  private

  def decorate(glossary_entries)
    glossary_entries.map do |glossary_entry|
      glossary_entry[:locale_glossary_entries].each do |locale, locale_glossary_entry|
        glossary_entry[:locale_glossary_entries][locale] = locale_glossary_entry.merge(
          edit_locale_entry_url:  edit_glossary_source_locale_url(glossary_entry["id"], locale_glossary_entry["id"]),
          approve_url:            approve_glossary_source_locale_url(glossary_entry["id"], locale_glossary_entry["id"]),
          reject_url:             reject_glossary_source_locale_url(glossary_entry["id"], locale_glossary_entry["id"])
        )
      end 
      glossary_entry.merge(
          add_locale_entry_url:   glossary_source_locales_url(glossary_entry["id"]),
          edit_source_entry_url:  edit_glossary_source_url(glossary_entry["id"])
      )
    end
  end
end
