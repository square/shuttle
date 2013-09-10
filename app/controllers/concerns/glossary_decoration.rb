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
    # glossary_entries.map do |glossary_entry|
    #   glossary_entry.as_json.merge(
    #       add_source_entry_url:   glossary_sources_url(format:'json'),
    #       add_locale_entry_url:   glossary_source_locales_url("REPLACEME_SOURCE", format:'json'),
    #       edit_source_entry_url:  
    #       edit_locale_entry_url:  
    #       approve_url:    approve_project_key_translation_url(translation.key.project, translation.key, translation, format: 'json'),
    #       reject_url:     reject_project_key_translation_url(translation.key.project, translation.key, translation, format: 'json'),
    #       translator:     translation.translator.as_json,
    #       reviewer:       translation.reviewer.as_json # not sure why it's necessary to explicitly include these, but it is
    #   )
    #  @approveLocaleEntryUrl, @rejectLocaleEntryUrl 
    end
  end
end
