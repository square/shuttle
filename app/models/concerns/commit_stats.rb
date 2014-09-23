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

# This is a collection of statistical methods for the Commit model.

module CommitStats
  extend ActiveSupport::Concern

  included do
    extend RedisMemoize
  end

  # @return [Fixnum] The number of approved Translations across all required
  #   under this Commit.

  def translations_done(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where(approved: true, rfc5646_locale: locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_done

  # @return [Fixnum] The number of Translations across all required locales
  #   under this Commit.

  def translations_total(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where(rfc5646_locale: locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_total

  # @return [Float] The fraction of Translations under this Commit that are
  #   approved, across all required locales.

  def fraction_done(*locales)
    locales = project.required_locales if locales.empty?
    translations_done(*locales)/translations_total(*locales).to_f
  end

  # @return [Fixnum] The total number of translatable base strings applying to
  #   this Commit.

  def strings_total
    keys.count
  end
  redis_memoize :strings_total

  # Calculates the total number of Translations that have not yet been
  # translated.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of Translations.

  def translations_new(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where(translated: false, rfc5646_locale: locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_new

  # Calculates the total number of Translations that have not yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of Translations.

  def translations_pending(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where('approved IS NOT TRUE').
        where(translated: true, rfc5646_locale: locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_pending

  # Calculates the total number of words across all Translations that have not
  # yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of words in the Translations' source copy.

  def words_pending(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where('approved IS NOT TRUE').
        where(translated: true, rfc5646_locale: locales.map(&:rfc5646)).sum(:words_count)
  end
  redis_memoize :words_pending

  # Calculates the total number of words across all Translations that have not
  # yet been translations.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of words in the Translations' source copy.

  def words_new(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where(translated: false, rfc5646_locale: locales.map(&:rfc5646)).sum(:words_count)
  end
  redis_memoize :words_new


  # @private
  def redis_memoize_key() to_param end
end
