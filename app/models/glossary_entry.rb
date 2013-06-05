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

require 'digest/sha2'

# A localization of some commonly used copy to a certain locale. Glossary
# entries must be reviewed by a reviewer before they are accepted; once they
# are, they will appear in tooltips to translators who are translating similar
# strings.
#
# Like Translations, glossary entries share a lot of duplicated information.
#
# Associations
# ============
#
# |              |                                           |
# |:-------------|:------------------------------------------|
# | `translator` | The {User} who performed the translation. |
# | `reviewer`   | The {User} who reviewed the translation.  |
#
# Properties
# ==========
#
# |                 |                                                    |
# |:----------------|:---------------------------------------------------|
# | `translated`    | If `true`, the copy has been translated.           |
# | `approved`      | If `true`, the copy has been approved for release. |
# | `source_locale` | The locale the copy is translated from.            |
# | `locale`        | The locale the copy is translated to.              |
#
# Metadata
# ========
#
# |               |                                                                         |
# |:--------------|:------------------------------------------------------------------------|
# | `source_copy` | The copy for the string in the base locale.                             |
# | `copy`        | The translated copy.                                                    |
# | `context`     | A human-readable explanation of what the glossary term is referring to. |

class GlossaryEntry < ActiveRecord::Base
  belongs_to :translator, class_name: 'User', foreign_key: 'translator_id', inverse_of: :authored_glossary_entries
  belongs_to :reviewer, class_name: 'User', foreign_key: 'reviewer_id', inverse_of: :reviewed_glossary_entries

  include HasMetadataColumn
  has_metadata_column(
      source_copy: {presence: true},
      copy:        {allow_nil: true},
      context:     {allow_nil: true},
  )

  extend SetNilIfBlank
  set_nil_if_blank :copy, :context

  extend PrefixField
  prefix_field :source_copy

  validates :source_rfc5646_locale,
            presence: true
  validates :rfc5646_locale,
            presence: true
  validates :source_copy_sha,
            presence: true

  extend DigestField
  digest_field :source_copy

  extend LocaleField
  locale_field :source_locale, from: :source_rfc5646_locale
  locale_field :locale

  extend SearchableField
  searchable_field :copy, language_from: :locale
  searchable_field :source_copy, language_from: :source_locale

  before_update :reset_reviewed

  BASE_LOCALE = "en"

  def reset_reviewed
    if copy_changed? && !base_entry? && !approved_changed?
      self.reviewer_id = nil
      self.approved    = nil
    end
    return true
  end

  def self.ensure_entries_exist_in_locale(locale_id)
    #this feels pretty in-elegant.
    base_entries = GlossaryEntry.where(:rfc5646_locale => BASE_LOCALE)
    # If there is the right number of entries in the locale, then short circuit
    return if base_entries.count == GlossaryEntry.where(:rfc5646_locale => locale_id).count

    # find the list of shas that are translated
    base_shas = base_entries.pluck(:source_copy_sha_raw)
    existing_entries = GlossaryEntry.where(source_copy_sha_raw: base_shas).where(rfc5646_locale: locale_id)
    existing_shas = existing_entries.pluck(:source_copy_sha_raw)

    # each base entry where there isn't an existing translated entry
    existing_shas = [''] if existing_shas.empty? # fix error causing no rows to be returned
    base_entries.where('source_copy_sha_raw NOT IN (?)', existing_shas).each do |entry|
      ge = GlossaryEntry.new
      ge.rfc5646_locale = locale_id
      ge.source_rfc5646_locale = BASE_LOCALE
      ge.source_copy = entry.source_copy
      ge.copy = ''
      ge.save!
    end
  end

  def as_translation_json
    [self.source_copy, self.copy]
  end

  private

  def base_entry?
    rfc5646_locale == BASE_LOCALE
  end
end
