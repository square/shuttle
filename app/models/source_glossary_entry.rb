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
# | `source_locale` | The locale the copy is translated from.            |
# | `locale`        | The locale the copy is translated to.              |
#
# Metadata
# ========
#
# |               |                                                                         |
# |:--------------|:------------------------------------------------------------------------|
# | `copy`        | The copy for the string.                                                |
# | `context`     | A human-readable explanation of what the glossary term is referring to. |
# | `notes`       | A human-readable explanation of what the glossary term is referring to. |

class SourceGlossaryEntry < ActiveRecord::Base
  has_many :locale_glossary_entries, :dependent => :delete_all, inverse_of: :source_glossary_entry
  #### TODO: ADD DUE DATE
  include HasMetadataColumn
  has_metadata_column(
      source_copy: {allow_nil: true},
      context:     {allow_nil: true},
      notes:       {allow_nil: true}
  )

  extend SetNilIfBlank
  set_nil_if_blank :context, :notes

  extend PrefixField
  prefix_field :source_copy

  validates :source_rfc5646_locale,
            presence: true
  validates :source_copy_sha,
            presence: true
  validates :source_copy_sha_raw, 
            uniqueness: true

  attr_readonly :source_rfc5646_locale

  extend DigestField
  digest_field :source_copy

  extend LocaleField
  locale_field :source_locale, from: :source_rfc5646_locale

  extend SearchableField
  searchable_field :source_copy, language_from: :source_locale

end
