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

require 'digest/sha2'

# A localization of some commonly used copy to a certain locale. Locale glossary
# entries must be reviewed by a reviewer before they are accepted; once they
# are, they will appear in tooltips to translators who are translating similar
# strings.
#
# Associations
# ============
#
# |                         |                                                         |
# |:------------------------|:--------------------------------------------------------|
# | `translator`            | The {User} who performed the translation.               |
# | `reviewer`              | The {User} who reviewed the translation.                |
# | `source_glossary_entry` | The {SourceGlossaryEntry} this entry is associated with |
#
# Properties
# ==========
#
# |              |                                                                                 |
# |:-------------|:--------------------------------------------------------------------------------|
# | `translated` | If `true`, the copy has been translated.                                        |
# | `approved`   | If `true`, the copy has been approved for release.                              |
# | `locale`     | The locale the copy is translated to.                                           |
# | `copy`       | The translated copy.                                                            |
# | `notes`      | A human-readable explanation of any additional notes for translators/reviewers. |


class LocaleGlossaryEntry < ActiveRecord::Base
  belongs_to :translator, class_name: 'User', foreign_key: 'translator_id', inverse_of: :authored_glossary_entries
  belongs_to :reviewer, class_name: 'User', foreign_key: 'reviewer_id', inverse_of: :reviewed_glossary_entries
  belongs_to :source_glossary_entry, inverse_of: :locale_glossary_entries

  extend SetNilIfBlank
  set_nil_if_blank :copy, :notes

  validates :rfc5646_locale,
            presence:   true,
            uniqueness: {case_sensitive: false, scope: [:source_glossary_entry_id]}
  validates :source_glossary_entry,
            presence: true
  validate :translator_cant_change_approved, :check_not_source_locale

  attr_readonly :rfc5646_locale

  extend LocaleField
  locale_field :locale

  before_update :reset_reviewed

  # Checks to ensure that the targeted locale is not the same as the source
  def check_not_source_locale
    if rfc5646_locale == source_glossary_entry.source_rfc5646_locale
      errors.add(:rfc5646_locale, :cant_equal_source_locale)
      return false
    end
    return true
  end

  # @private Used to convert Locale Glossary Entries into a translation json
  def as_translation_json
    if copy.blank?
      return nil
    else
      return [source_glossary_entry.source_copy, copy]
    end
  end

  # @private
  def to_param() rfc5646_locale end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:only] = Array.wrap(options[:only])
    options[:only] << :id << :copy << :notes << :translated << :approved

    super(options)
  end

  private

  # Checks to ensure that a translator can't modify an approved entry.
  def translator_cant_change_approved
    if approved? && translator && !translator.reviewer?
      errors.add :base, :illegal_change
      return false
    end
    return true
  end

  # Resets the reviewer and approval status if the copy is ever changed.
  def reset_reviewed
    if copy_changed? && !approved_changed?
      if copy_change[0] != copy_change[1]
        self.reviewer_id = nil
        self.approved    = nil
      end
    end
    return true
  end
end
