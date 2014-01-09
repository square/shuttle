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

# An entry in Shuttle's translation memory. Every time a Translation is
# approved, an entry is added (or updated) in the translation memory, acting as
# a historical record of that translation. Then, when the translator needs to
# make future translators, s/he can leverage the translation memory to quickly
# find prior translations that can be of use.
#
# A translation unit is uniquely described by its source content, translated
# content, the source locale, and the target locale.
#
# Properties
# ==========
#
# |                 |                                      |
# |:----------------|:-------------------------------------|
# | `source_copy`   | The source string.                   |
# | `copy`          | The translated string.               |
# | `source_locale` | The locale of the source string.     |
# | `locale`        | The locale of the translated string. |

class TranslationUnit < ActiveRecord::Base
  before_validation { |obj| obj.source_copy = '' if obj.source_copy.nil? }

  extend DigestField
  digest_field :source_copy, scope: :source_copy_matches
  digest_field :copy, scope: :copy_matches

  extend LocaleField
  locale_field :source_locale, from: :source_rfc5646_locale
  locale_field :locale

  include Tire::Model::Search
  include Tire::Model::Callbacks
  mapping do
    indexes :copy, analyzer: 'snowball'
    indexes :source_copy, analyzer: 'snowball'
    indexes :id, type: 'string', index: :not_analyzed
    indexes :rfc5646_locale, analyzer: 'simple'
  end

  validates :source_rfc5646_locale,
            presence: true
  validates :rfc5646_locale,
            presence: true
  validates :copy_sha_raw,
            presence: true
  validates :source_copy_sha_raw,
            presence:   true,
            uniqueness: {scope: [:copy_sha_raw, :source_rfc5646_locale, :rfc5646_locale]}
  validate :locale_and_source_locale_different

  attr_readonly :source_rfc5646_locale, :rfc5646_locale

  scope :exact_matches, ->(translation, locale_override=nil) {
    locale = locale_override || translation.locale
    source_copy_matches(translation.source_copy).where(
        source_rfc5646_locale: translation.source_rfc5646_locale,
        rfc5646_locale:        locale.rfc5646
    )

  }

  # Stores an approved Translation's source and translated copy into the
  # translation memory. Does nothing if given a base translation or an
  # unapproved translation.
  #
  # @param [Translation] translation A Translation to store.

  def self.store(translation)
    return unless translation.approved? && !translation.base_translation?

    TranslationUnit.where(
        source_rfc5646_locale: translation.source_rfc5646_locale,
        rfc5646_locale:        translation.rfc5646_locale
    ).source_copy_matches(translation.source_copy).
        copy_matches(translation.copy).create_or_update!(
            source_copy: translation.source_copy,
            copy:        translation.copy)
  end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:except])
    options[:except] << :source_rfc5646_locale << :rfc5646_locale
    options[:except] << :searchable_source_copy << :searchable_copy
    options[:except] << :source_copy_sha_raw << :copy_sha_raw

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :source_locale << :locale

    super options
  end

  private

  def locale_and_source_locale_different
    errors.add(:rfc5646_locale, :invalid) if locale == source_locale
  end
end
