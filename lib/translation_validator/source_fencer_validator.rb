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

  # Checks if the source strings violates their own fencers.
  class SourceFencerValidator < Base
    IGNORE_FENCERS = %w(Html)

    # implementations for Validator::Base
    def run
      Rails.logger.info("#{SourceFencerValidator} - starting source string validation: #{@job.project.job_type} with id #{@job.id}")

      suspicious_keys_errors = find_suspicious_keys_errors(find_pending_keys)
      Rails.logger.info("#{SourceFencerValidator} - found #{suspicious_keys_errors.count} suspicious source strings")
      return if suspicious_keys_errors.blank?

      FencerValidationMailer.suspicious_source_found(@job, suspicious_keys_errors).deliver_now
      Rails.logger.info("#{SourceFencerValidator} - email sent for these suspicious source strings")
    end

    # find new translations, which are created after the job.
    def find_pending_keys
      @job.translations.includes(key: :project).where(translated: [nil, false]).where("translations.created_at >= ?", @job.created_at).map(&:key).uniq
    end

    # returns keys failed to pass their fencers
    def find_suspicious_keys_errors(keys)
      suspicious_keys_errors = []
      keys.each do |key|
        if key.fencers.present?
          offensive_fencers = key.fencers.reject do |fencer|
            begin
              IGNORE_FENCERS.include?(fencer) || Fencer.const_get(fencer).valid?(key.source_copy)
            rescue
              false
            end
          end
          if offensive_fencers.present?
            suspicious_keys_errors << [key, "Violate fencers: #{offensive_fencers.join(', ')}"]
          end
        end
      end
      suspicious_keys_errors
    end
  end
end
