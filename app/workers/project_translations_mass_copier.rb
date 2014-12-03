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

# It copies all translations of a project (their `copy` fields) from one locale to another.
# It only copies from approved source translations into not-translated target translations.
# It skips readiness hooks and preserves the approved state.

class ProjectTranslationsMassCopier
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
    errors = ProjectTranslationsMassCopier.find_locale_errors(project, from_rfc5646_locale, to_rfc5646_locale)
    raise ArgumentError, errors.join(". ") if errors.present?

    key_ids = key_ids_with_copyable_translations(project, from_rfc5646_locale, to_rfc5646_locale)
    return if key_ids.empty?

    mass_copier_batch(project_id, from_rfc5646_locale, to_rfc5646_locale).jobs do
      key_ids.each do |key_id|
        KeyTranslationCopier.perform_once(key_id, from_rfc5646_locale, to_rfc5646_locale)
      end
    end
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
    return [I18n.t('workers.translations_mass_copier.project_translations_adder_and_remover_batch_still_running')] if project.translations_adder_and_remover_batch_status
    []
  end

  # Returns the key ids with translations which can be copied from the given source locale to the given target locale.
  # Should only be called in the perform method of this worker.
  # This method is particularly useful for projects with a lot of keys, and a small number of not finished translations.
  # The reason is that it contains a few of the filters KeyTranslationCopier uses, such as from `approved` to `not translated` and ` not base`.
  # And, these copied filters improve performance since it prevents calling KeyTranslationCopier if it's not necessary.
  # Nevertheless, the source of truth for filters should be the KeyTranslationCopier worker.

  # @return [Array<Fixnum>] an array of key ids

  # @private
  def key_ids_with_copyable_translations(project, from_rfc5646_locale, to_rfc5646_locale)
    from_translations_key_ids = project.translations.approved.where(rfc5646_locale: from_rfc5646_locale).pluck(:key_id)
    to_translations_key_ids = project.translations.not_base.not_translated.where(rfc5646_locale: to_rfc5646_locale).pluck(:key_id)
    from_translations_key_ids & to_translations_key_ids
  end

  # Returns a new batch every time it's called. Runs ProjectTranslationsMassCopier::Finisher on success.
  # Should only be called in the perform method of this worker.

  # @return [Sidekiq::Batch] a sidekiq batch

  # @private
  def mass_copier_batch(project_id, from_rfc5646_locale, to_rfc5646_locale)
    b = Sidekiq::Batch.new
    b.description = "Project Translations Mass Copier #{project_id} (#{from_rfc5646_locale} -> #{to_rfc5646_locale})"
    b.on :success, ProjectTranslationsMassCopier::Finisher, project_id: project_id
    b
  end

  include SidekiqLocking

  # Contains hooks run by Sidekiq upon completion of a ProjectTranslationsMassCopier batch.

  class Finisher

    # Run by Sidekiq after a ProjectTranslationsMassCopier batch finishes successfully.
    # Triggers a ProjectDescendantsRecalculator job

    def on_success(_status, options)
      ProjectDescendantsRecalculator.perform_once options['project_id']
    end
  end
end
