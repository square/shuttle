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

# Represents an association between 2 locales.
# It's used in multi-lingual translation workbench for fast translations into multiple
# associated locales.

class LocaleAssociation < ActiveRecord::Base
  # VALIDATIONS
  validates :checked, inclusion: { in: [true, false] }
  validates :uncheckable, inclusion: { in: [true, false] }
  validates :source_rfc5646_locale, presence: true
  validates :target_rfc5646_locale, presence: true
  validates :target_rfc5646_locale, uniqueness: { scope: :source_rfc5646_locale }
  validate :target_rfc5646_locale_cannot_be_equal_to_source
  validate :iso639s_should_match, if: "source_locale && target_locale"

  extend LocaleField
  locale_field :source_locale, from: :source_rfc5646_locale
  locale_field :target_locale, from: :target_rfc5646_locale

  # @private
  def as_json(options={})
    options[:except] ||= []
    options[:except] << :created_at << :updated_at
    super options
  end

  private

  def target_rfc5646_locale_cannot_be_equal_to_source
    if source_rfc5646_locale == target_rfc5646_locale
      errors.add(:target_rfc5646_locale, :cant_equal_to_source_locale)
    end
  end

  def iso639s_should_match
    if source_locale.iso639 != target_locale.iso639
      errors.add(:target_rfc5646_locale, :iso639_doesnt_match_source_iso639)
    end
  end
end
