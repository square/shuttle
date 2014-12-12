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

# This abstracts out some common Locale logic, used by the Project and Article models.

require 'active_support/concern'

module CommonLocaleLogic
  extend ActiveSupport::Concern

  included do
    serialize :targeted_rfc5646_locales, Hash

    extend LocaleField
    locale_field :base_locale, from: :base_rfc5646_locale
    locale_field :locale_requirements,
                 from:   :targeted_rfc5646_locales,
                 reader: ->(values) { values.inject({}) { |hsh, (k, v)| hsh[Locale.from_rfc5646(k)] = v; hsh } },
                 writer: ->(values) { values.inject({}) { |hsh, (k, v)| hsh[k.rfc5646] = v; hsh } }

    validates :base_rfc5646_locale, presence: true
    validates :base_rfc5646_locale, format: { with: Locale::RFC5646_FORMAT }, if: "base_rfc5646_locale.present?"
    validate :prevent_base_locale_from_changing, on: :update

    validates :targeted_rfc5646_locales, presence: true
    validate :require_valid_targeted_rfc5646_locales_hash, if: "targeted_rfc5646_locales.present?"
  end

  # Validates the validity of the targeted_rfc5646_locales hash
  # Doesn't validate its presence
  def require_valid_targeted_rfc5646_locales_hash
    if !targeted_rfc5646_locales.keys.all? { |k| k.kind_of?(String) } ||
       !targeted_rfc5646_locales.values.all? { |v| v == true || v == false }
      errors.add(:targeted_rfc5646_locales, :invalid)
    end
  end

  # Prevent users from changing the base_rfc5646_locale of the including model
  def prevent_base_locale_from_changing
    errors.add(:base_rfc5646_locale, :readonly) if base_rfc5646_locale_changed?
  end

  # @return [Array<Locale>] The locales the including model can be localized to.
  def targeted_locales()
    locale_requirements.keys
  end

  # @return [Array<Locale>] The locales the including model *must* be localized to.
  def required_locales()
    locale_requirements.select { |_, req| req }.map(&:first)
  end

  # @return [Array<String>] The rfc5646 locales the including model *must* be localized to.
  def required_rfc5646_locales
    targeted_rfc5646_locales.select { |_, req| req }.map(&:first)
  end

  # @return [Array<String>] The rfc5646 locales the including model does not have to be,
  #       but *may* optionally be localized to.
  def other_rfc5646_locales
    targeted_rfc5646_locales.select { |_, req| !req }.map(&:first)
  end
end
