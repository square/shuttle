# Copyright 2019 Square Inc.
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

module TranslationValidator

  # This translation_validator walks through the pending translations and automatically migrates the translation from existing TMs.
  # The order to match the translation:
  #   - from same project
  #   - from same job type
  #   - from other job type
  class TranslationAutoMigration < Base

    EN_BASE_LOCALES = %w(en en-US)
    AUTO_TRANSLATION_MIGRATION_NOTE = 'AutoTM'

    # implementations for Validator::Base
    def run
      Rails.logger.info("#{TranslationAutoMigration} - starting auto translation migration: #{@job.project.job_type} with id #{@job.id}")

      pending_translations = find_pending_translations
      Rails.logger.info("#{TranslationAutoMigration} - found #{pending_translations.count} pending translations")
      return if pending_translations.blank?

      migrated_translations = []
      pending_translations.each do |translation|
        approved_translations = find_approved_translations(translation)
        matched_transaltion = find_approved_translation_from_project(translation, approved_translations) ||
            find_approved_translation_from_job_type(translation, approved_translations) ||
            find_approved_translation_from_other(translation, approved_translations)
        if matched_transaltion
          migrate_translation(translation, matched_transaltion)
          migrated_translations << translation
        end
      end
      Rails.logger.info("#{TranslationAutoMigration} - migrated #{migrated_translations.count} translations")
      return if migrated_translations.blank?

      keys = migrated_translations.map(&:key).uniq
      keys.map(&:recalculate_ready!)
      Rails.logger.info("#{TranslationAutoMigration} - recalculated #{keys.count} keys for translations")
    end

    def find_pending_translations
      @job.translations.includes(key: :project).where(translated: [nil, false]).where("translations.created_at >= ?", @job.created_at)
    end

    # find existing approved translations, ordered by :updated_at descending
    def find_approved_translations(translation)
      base_locales = EN_BASE_LOCALES.include?(translation.source_rfc5646_locale) ? EN_BASE_LOCALES : translation.source_rfc5646_locale
      Translation.includes(key: :project).where(source_copy: translation.source_copy, source_rfc5646_locale: base_locales, rfc5646_locale: translation.rfc5646_locale, approved: true).order(updated_at: :desc)
    end

    # find existing translation from the same project
    def find_approved_translation_from_project(translation, approved_translations)
      project_id = translation.key.project.id
      approved_translations.detect { |t| t.key.project.id == project_id }
    end

    # find existing translation from same job_type
    def find_approved_translation_from_job_type(translation, approved_translations)
      job_type = translation.key.project.job_type
      approved_translations.detect { |t| t.key.project.job_type == job_type }
    end

    # find existing translation from other job_types
    def find_approved_translation_from_other(_translation, approved_translations)
      approved_translations.first
    end

    def migrate_translation(translation, approved_translation)
      translation.copy = approved_translation.copy
      translation.translated = true
      translation.notes = "#{AUTO_TRANSLATION_MIGRATION_NOTE}:#{approved_translation.id} #{translation.notes}"
      translation.translation_date = Time.now
      translation.save!
    end
  end
end
