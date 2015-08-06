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
  include ActionView::Helpers::NumberHelper

  private

  def decorate(translations)
    translations.map do |translation|
      translation.as_json.merge(
          key:              translation.key.as_json,
          url:              project_key_translation_path(translation.key.project, translation.key, translation),
          edit_url:         edit_project_key_translation_path(translation.key.project, translation.key, translation),
          suggestion_url:   match_project_key_translation_path(translation.key.project, translation.key, translation, format: 'json'),
          fuzzy_match_url:  fuzzy_match_project_key_translation_path(translation.key.project, translation.key, translation, format: 'json'),
          article_name:     translation.key.article.try(:name),
          article_url:      translation.belongs_to_article? ? api_v1_project_article_path(translation.key.project.id, translation.key.article.name) : nil,
          status:           translation_status(translation),
          translator:       translation.translator.as_json,
          reviewer:         translation.reviewer.as_json, # not sure why it's necessary to explicitly include these, but it is
          multi_updateable_translations_and_locale_associations: multi_updateable_translations_and_locale_associations(translation),
      )
    end
  end

  private

  def multi_updateable_translations_and_locale_associations(primary_translation)
    TranslationUpdateMediator.multi_updateable_translations_to_locale_associations_hash(primary_translation).
        sort_by { |translation, la| translation.rfc5646_locale }.
        reduce([]) do |arr, (translation, locale_association)|
          arr <<  { translation:
                      translation.as_json(only: [:rfc5646_locale]).merge(
                        status:     translation_status(translation),
                        edit_path:  ERB::Util.h(edit_project_key_translation_path(translation.key.project, translation.key, translation)),
                        similarity: similarity(translation, primary_translation)),
                    locale_association: {
                      checked:          locale_association_checked?(         locale_association, translation),
                      uncheck_disabled: locale_association_uncheck_disabled?(locale_association, translation)
                    }}
          arr
        end
  end

  def locale_association_checked?(locale_association, translation)
    locale_association.checked && !translation.key.project.disable_locale_association_checkbox_settings
  end

  def locale_association_uncheck_disabled?(locale_association, translation)
    locale_association.uncheck_disabled && !translation.key.project.disable_locale_association_checkbox_settings
  end

  def translation_status(translation)
    if translation.approved
      'approved'
    elsif translation.approved == false
      'rejected'
    elsif translation.translated
      'translated'
    else
      ''
    end
  end

  def similarity(t1, t2)
    number_to_percentage(t1.copy.similar(t2.copy), precision: 0) if t1.translated? && t2.translated?
  end
end
