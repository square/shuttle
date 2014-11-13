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

# Mixin that adds a `decorate` method that adds additional information to
# Translation JSON serializations.

module TranslationDecoration
  private

  def decorate(translations)
    translations.map do |translation|
      translation.as_json.merge(
          key:              translation.key.as_json,
          url:              project_key_translation_url(translation.key.project, translation.key, translation),
          edit_url:         edit_project_key_translation_url(translation.key.project, translation.key, translation),
          approve_url:      approve_project_key_translation_url(translation.key.project, translation.key, translation, format: 'json'),
          reject_url:       reject_project_key_translation_url(translation.key.project, translation.key, translation, format: 'json'),
          suggestion_url:   match_project_key_translation_url(translation.key.project, translation.key, translation, format: 'json'),
          fuzzy_match_url:  fuzzy_match_project_key_translation_url(translation.key.project, translation.key, translation, format: 'json'),
          translator:       translation.translator.as_json,
          reviewer:         translation.reviewer.as_json, # not sure why it's necessary to explicitly include these, but it is
          multi_updateable_translations_and_locale_associations: multi_updateable_translations_and_locale_associations(translation),
      )
    end
  end

  def multi_updateable_translations_and_locale_associations(translation)
    TranslationUpdateMediator.multi_updateable_translations_to_locale_associations_hash(translation).
        sort_by { |translation, la| translation.rfc5646_locale }.
        reduce([]) do |arr, (translation, locale_association)|
          arr << {translation: translation.as_json(only: [:rfc5646_locale]), locale_association: locale_association.as_json(only: [:checked, :uncheckable]) }
          arr
        end
  end
end
