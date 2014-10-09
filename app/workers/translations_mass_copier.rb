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

# It copies all translations (their `copy` fields) from one locale to another.
# It only copies from approved source translations into not-translated target translations.
# It skips readiness hooks and preserves the approved state.

class TranslationsMassCopier
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] project_id The ID of a Project.
  # @param [String] from_rfc5646_locale The RFC 5646 code of a locale to copy
  #   existing translations from.
  # @param [String] to_rfc5646_locale The RFC 5646 code of a locale to copy
  #   existing translations to.

  def perform(project_id, from_rfc5646_locale, to_rfc5646_locale)
    project = Project.find(project_id)

    # This check was performed in the projects controller, but needs to be performed again because things
    # may have changed since then.
    errors = TranslationsMassCopier.find_locale_errors(project, from_rfc5646_locale, to_rfc5646_locale)
    raise ArgumentError, errors.join(". ") if errors.present?

    # filter by current source_locale in case there are random translations floating around with different source_locales
    query_template = project.translations.where(source_rfc5646_locale: project.base_rfc5646_locale)

    # Only copy from approved translations
    from_translations = query_template.approved.where(rfc5646_locale: from_rfc5646_locale)
    from_translations_indexed_by_key_id = from_translations.index_by(&:key_id)

    # Only copy into not-translated not-base translations
    to_translations = query_template.not_base.not_translated.where(rfc5646_locale: to_rfc5646_locale)

    # Actually perform the copying operations
    to_translations.each do |to_translation|
      from_translation = from_translations_indexed_by_key_id[to_translation.key_id]
      if from_translation && from_translation.source_copy == to_translation.source_copy
        to_translation.update! copy: from_translation.copy,
                               approved: true,
                               skip_readiness_hooks: true,
                               preserve_reviewed_status: true
      end
    end

    # readiness hooks were skipped above, so we need to run them now
    BatchKeyAndCommitRecalculator.perform_once project.id
  end

  def self.find_locale_errors(project, from_rfc5646_locale, to_rfc5646_locale)
    # cannot copy to the 'from' locale
    return [I18n.t('workers.translations_mass_copier.from_and_to_cannot_be_equal')] if from_rfc5646_locale == to_rfc5646_locale

    errors = []

    # make sure inputted locales are valid
    from_locale, to_locale = [[:source, from_rfc5646_locale], [:target, to_rfc5646_locale]].map do |kind, rfc5646_locale|
      locale = nil
      if rfc5646_locale.present?
        locale = Locale.from_rfc5646(rfc5646_locale)
        errors << I18n.t('workers.translations_mass_copier.invalid_rfc5646_locale', kind: kind) unless locale
      else
        errors << I18n.t('workers.translations_mass_copier.invalid_rfc5646_locale', kind: kind)
      end
      locale
    end
    return errors if errors.present?

    # can only copy from the base or one of the targeted locales
    unless (project.targeted_rfc5646_locales.keys + [project.base_rfc5646_locale]).include?(from_rfc5646_locale)
      errors << I18n.t('workers.translations_mass_copier.from.not_a_targeted_or_base_locale')
    end

    # can only copy to one of the targeted locales
    unless project.targeted_rfc5646_locales.keys.include?(to_rfc5646_locale)
      errors << I18n.t('workers.translations_mass_copier.to.not_a_targeted_locale')
    end

    # cannot copy to the base locale
    if project.base_rfc5646_locale == to_rfc5646_locale
      errors << I18n.t('workers.translations_mass_copier.to.cannot_copy_to_projects_base_locale')
    end

    return errors if errors.present?

    # Can only copy within the same language family.
    # At the time of writing, this constraint is enough.
    # However, it may need to be adjusted according to needs as Shuttle evolves.
    if from_locale.iso639 != to_locale.iso639
      return [I18n.t('workers.translations_mass_copier.iso639s_doesnt_match')]
    end

    # Don't run this if Project translation adder is still running
    return [I18n.t('workers.translations_mass_copier.translation_adder_batch_still_running')] if project.translation_adder_batch_status
    []
  end

  include SidekiqLocking
end
