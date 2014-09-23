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
# All of these methods are cached, and there will be a latency before they
# return correct values. You should directly calculate values if you
# need real-time accurate values.

module CommitStats
  extend ActiveSupport::Concern

  included do
    serialize :stats, Hash
  end

  # Recalculates the stats for this Key, sets the `stats` field.
  # Should not depend on the commit's ready state since recalculate_stats! is not guaranteed to run before or after
  # recalculate_ready!

  def recalculate_stats!
    hsh = { strings_total: keys.count, locale_specific: {} }

    translation_groups = translations.not_base.group("rfc5646_locale, translated, approved")
    translation_groups = translation_groups.select("rfc5646_locale, translated, approved, count(*) as translations_count, sum(words_count) as words_count")

    translation_groups.each do |tg|
      hsh[:locale_specific][tg.rfc5646_locale] ||= { }
      state = (tg.approved? ? :approved : (tg.translated? ? :pending : :new))

      [:translations_count, :words_count].each do |field|
        hsh[:locale_specific][tg.rfc5646_locale][state] ||= {}
        hsh[:locale_specific][tg.rfc5646_locale][state][field] ||= 0
        hsh[:locale_specific][tg.rfc5646_locale][state][field] += tg.send(field)
      end
    end

    update stats: hsh
  end

  # @return [Fixnum] The total number of translatable base strings applying to
  #   this Commit.

  def strings_total
    fetch_stat(:strings_total, 0)
  end

  # @return [Fixnum] The number of approved Translations across all required
  #   under this Commit.

  def translations_done(*locales)
    requested_locales(*locales).sum { |locale| fetch_stat(:locale_specific, locale.rfc5646, :approved, :translations_count, 0) }
  end

  # Calculates the total number of Translations that have not yet been
  # translated.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of Translations.

  def translations_new(*locales)
    requested_locales(*locales).sum { |locale| fetch_stat(:locale_specific, locale.rfc5646, :new, :translations_count, 0) }
  end

  # Calculates the total number of Translations that have not yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of Translations.

  def translations_pending(*locales)
    requested_locales(*locales).sum { |locale| fetch_stat(:locale_specific, locale.rfc5646, :pending, :translations_count, 0) }
  end

  # @return [Fixnum] The number of Translations across all required locales
  #   under this Commit.

  def translations_total(*locales)
    translations_done(*locales) + translations_pending(*locales) + translations_new(*locales)
  end

  # @return [Float] The fraction of Translations under this Commit that are
  #   approved, across all required locales.

  def fraction_done(*locales)
    translations_done(*locales)/translations_total(*locales).to_f
  end

  # Calculates the total number of words across all Translations that have not
  # yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of words in the Translations' source copy.

  def words_pending(*locales)
    requested_locales(*locales).sum { |locale| fetch_stat(:locale_specific, locale.rfc5646, :pending, :words_count, 0) }
  end

  # Calculates the total number of words across all Translations that have not
  # yet been translations.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of words in the Translations' source copy.

  def words_new(*locales)
    requested_locales(*locales).sum { |locale| fetch_stat(:locale_specific, locale.rfc5646, :new, :words_count, 0) }
  end

  private

  def requested_locales(*locales)
    locales.empty? ? project.required_locales : locales
  end

  def fetch_stat(*args, default)
    result = stats
    args.each do |arg|
      result = result.try! :[], arg
    end
    result || default
  end
end
