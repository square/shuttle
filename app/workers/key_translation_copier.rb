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

# It copies a key's translation from one locale to another.
# It only copies from approved source translations into not-translated & not-base target translations.
# It skips readiness hooks and preserves the approved state.

class KeyTranslationCopier
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] key_id The ID of a Key.
  # @param [String] from_rfc5646_locale The RFC 5646 code of a locale to copy existing translation from.
  # @param [String] to_rfc5646_locale The RFC 5646 code of a locale to copy  existing translation to.

  def perform(key_id, from_rfc5646_locale, to_rfc5646_locale)
    key = Key.find(key_id)
    project = key.project

    # filter by project's base locale in case there are random translations floating around with different source_locales
    query_template = key.translations.where(source_rfc5646_locale: project.base_rfc5646_locale)

    # Only copy from approved translations
    from_translation = query_template.approved.where(rfc5646_locale: from_rfc5646_locale).last

    # Only copy into not-translated not-base translations
    to_translation = query_template.not_base.not_translated.where(rfc5646_locale: to_rfc5646_locale).last

    # Make sure translation records exist
    if from_translation && to_translation
      to_translation.update! copy: from_translation.copy,
                             approved: true,
                             preserve_reviewed_status: true
    end
  end

  include SidekiqLocking
end
