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

# Source glossary entries encapsulate commonly used copies which need to be 
# translated for a specific locale.  Note that copies from a single source 
# must be unique.  
#
# Associations
# ============
#
# |                           |                                                                           |
# |:--------------------------|:--------------------------------------------------------------------------|
# | `locale_glossary_entries` | Locale specific glossary entries that are translations of the source copy |
# 
# Properties
# ==========
#
# |                 |                                                                        |
# |:----------------|:-----------------------------------------------------------------------|
# | `source_locale` | The locale the copy that needs to be translated is from.               |
# | `source_copy`   | The copy for the string.                                               |
# | `context`       | A human-readable explanation of the context in which the copy is used. |
# | `notes`         | A human-readable explanation of any additional notes for translators.  |
# | `due_date`      | The expected date when a glossary entry is due to be translated.       |

class SourceGlossaryEntry < ActiveRecord::Base
  has_many :locale_glossary_entries, dependent: :destroy, inverse_of: :source_glossary_entry

  extend SetNilIfBlank
  set_nil_if_blank :context, :notes, :due_date

  validates :source_rfc5646_locale,
            presence: true
  validates :source_copy,
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

  def as_json(options=nil)
    options ||= {}

    options[:only] = Array.wrap(options[:only])
    options[:only] << :id << :source_copy << :source_locale << :context << :notes

    super(options).merge(locale_glossary_entries: locale_glossary_entries.inject({}) do |memo, cur|
      memo[cur.rfc5646_locale] = cur.as_json
      memo
    end)
  end

end
