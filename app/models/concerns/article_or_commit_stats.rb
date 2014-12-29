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

# Includes the helper statistics methods for a {Commit} or an {Article}.
#
# This abstract module expects to be included in a more concrete module/class
# which implements the following methods:
#   - `active_translations`
#   - `active_keys`

module ArticleOrCommitStats

  # Calculates the total number of Translations that have not yet been
  # translated.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of translations that have not been translated.

  def translations_new(*locales)
    fetch_stat(locales, :new, :translations_count)
  end

  # Calculates the total number of Translations that have not yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of translations that are translated and not yet approved.

  def translations_pending(*locales)
    fetch_stat(locales, :pending, :translations_count)
  end

  # Calculates the total number of Translations that are not translated and not yet approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of translations that are not done (not translated and not yet approved).

  def translations_not_done(*locales)
    translations_new(*locales) + translations_pending(*locales)
  end

  # @return [Fixnum] The number of approved Translations across all required
  #   under this Commit.

  def translations_done(*locales)
    fetch_stat(locales, :approved, :translations_count)
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
  # yet been translated.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of new words in the Translations' source copy.

  def words_new(*locales)
    fetch_stat(locales, :new, :words_count)
  end

  # Calculates the total number of words across all Translations that have not
  # yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of words in the Translations' source copy that haven't been approved.

  def words_pending(*locales)
    fetch_stat(locales, :pending, :words_count)
  end

  # @return [Fixnum] The total number of translatable base strings applying to
  #   this Commit.

  def strings_total
    active_keys.count
  end

  # Calculates the stats for this Key.
  #
  # @return [Hash<String, Hash<String, Fixnum>>] stats The hash whose key is a state (:new, :pending, or :approved),
  #   and value is another hash whose key is either :translations_count or :words_count, and value is the count as fixnum.

  def stats(*locales)
    cached = @_stats.try(:[], locales)
    return cached if cached

    locales = required_locales if locales.empty?
    translation_groups = active_translations.where(rfc5646_locale: locales.map(&:rfc5646))
    translation_groups = translation_groups.group("translated, approved").select("translated, approved, count(*) as translations_count, sum(words_count) as words_count")

    hsh = {}
    translation_groups.each do |tg|
      state = translation_state(tg)
      hsh[state] ||= {}
      [:translations_count, :words_count].each do |field|
        hsh[state][field] ||= 0
        hsh[state][field] += tg.send(field)
      end
    end

    @_stats ||= {}
    @_stats[locales] = hsh
  end

  private

  def translation_state(t)
    if t.approved?
      :approved
    elsif t.translated?
      :pending
    else
      :new
    end
  end

  def fetch_stat(locales, state, field, default=0)
    stats(*locales).try!(:[], state).try!(:[], field) || default
  end
end
