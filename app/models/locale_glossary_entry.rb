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

class LocaleGlossaryEntry < ActiveRecord::Base
  belongs_to :translator, class_name: 'User', foreign_key: 'translator_id', inverse_of: :authored_glossary_entries
  belongs_to :reviewer, class_name: 'User', foreign_key: 'reviewer_id', inverse_of: :reviewed_glossary_entries
  belongs_to :source_glossary_entry, inverse_of: :locale_glossary_entries

  include HasMetadataColumn
  has_metadata_column(
      copy:        {allow_nil: true},
      notes:       {allow_nil: true}
  )

  extend SetNilIfBlank
  set_nil_if_blank :copy, :notes

  validates :rfc5646_locale,
            presence: true,
            uniqueness: { case_sensitive: false, scope: [ :source_glossary_entry_id ] }
  ### TODO: Don't allow nil copy anymore.
  validates :source_glossary_entry,
            presence: true

  attr_readonly :rfc5646_locale

  extend LocaleField
  locale_field :locale

  extend SearchableField
  searchable_field :copy, language_from: :locale

  before_save :check_not_source_locale
  before_update :reset_reviewed

  # Ensure only 1 entry per language
  def check_not_source_locale
    if self.rfc5646_locale == self.source_glossary_entry.source_rfc5646_locale 
      return false
    end 
    return true
  end 

  def reset_reviewed
    if copy_changed? && !approved_changed?
      self.reviewer_id = nil
      self.approved    = nil
    end
    return true
  end

end
