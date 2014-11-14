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
#
# It's used in multi-lingual translation workbench for fast translations into multiple
# associated locales.
#
# `uncheck_disabled` can only be set if `checked` is set.
#
# For example, let's assume that you have projects with 'fr' and 'fr-CA' as targeted locales.
# In most cases, their translations would be the same. So, you would want to create a
# {LocaleAssociation} from 'fr' to 'fr-CA', and set `checked` to true and `uncheck_disabled` to false.
# From then on, whenever a translator is translating, say from 'en', to 'fr', they will see a
# checkbox for 'fr-CA' which is checked by default. Translator can uncheck it if they think
# the translations will not be the same. If it's checked when the translator submits the form,
# the translation copy will be copied to both 'fr' & 'fr-CA' translations.
#
# Sometimes, you may want keep a 1:1 relationship between locales. In such cases, you can
# set `checked` & `uncheck_disabled` both. Then, the translator should not be able to uncheck it.
# However, these settings apply to translation workbench only. A translator can edit any single
# translation by going to its edit page even regardless of LocaleAssociations.
#
# Properties
# ==========
#
# |                         |                                                                                     |
# |:------------------------|:------------------------------------------------------------------------------------|
# | `checked`               | Whether or not the checkbox for this locale association will be checked by default. |
# | `uncheck_disabled`      | Whether or not the checkbox will allow unchecking if it's checked by default.       |
# | `source_rfc5646_locale` | The source locale for the association.                                              |
# | `target_rfc5646_locale` | The target locale for the association.                                              |

class LocaleAssociation < ActiveRecord::Base
  # VALIDATIONS
  validates :checked, inclusion: { in: [true, false] }
  validates :uncheck_disabled, inclusion: { in: [true, false] }
  validates :source_rfc5646_locale, presence: true
  validates :target_rfc5646_locale, presence: true
  validates :target_rfc5646_locale, uniqueness: { scope: :source_rfc5646_locale }
  validate :target_rfc5646_locale_cannot_be_equal_to_source
  validate :iso639s_should_match, if: "source_locale && target_locale"
  validate :cannot_disable_uncheck_if_its_not_checked

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

  def cannot_disable_uncheck_if_its_not_checked
    if uncheck_disabled && !checked
      errors.add(:uncheck_disabled, :cannot_disable_uncheck_if_its_not_checked)
    end
  end
end
