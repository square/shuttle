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

class HomePresenter
  include ActionView::Helpers::TextHelper

  def initialize(commits, locales)
    @commits, @locales = commits, locales
  end

  def full_description(commit)
    commit.description || '-'
  end

  def short_description(commit)
    truncate(full_description(commit), length: 50)
  end

  def due_date_class(commit)
    if commit.due_date < 2.days.from_now.to_date
      'due-date-very-soon'
    elsif commit.due_date < 5.days.from_now.to_date
      'due-date-soon'
    else
      nil
    end
  end

  # Returns the count of pending/new translations/words for a commit. Ex: `commit_stat(commit, :translations, :new)`
  #
  # @param [Commit] commit The commit for which stat will be returned.
  # @param [String] type The type for which stat will be returned. Can be :translations or :words
  # @param [String] state The state for which stat will be returned. Can be :new or :pending
  #
  # @return [Fixnum] the value of the stat for the given commit, type or state

  def commit_stat(commit, type, state)
    @_all_commit_stats ||= parse_commit_stats(translation_groups_with_stats) # memoize
    @_all_commit_stats[commit.id][type][state]
  end

  private

  # Prepares a query which will group translations in a way that we can extract stats from them easily afterwards.
  # Queries for not_approved translations.

  def translation_groups_with_stats
    query = Translation.not_base.not_approved.joins(:commits_keys)
    query = query.where(commits_keys: { commit_id: @commits.map(&:id) } )
    query = query.where(translations: { rfc5646_locale: @locales.map(&:rfc5646) }) if @locales.present?
    query = query.group("commit_id, translated, rfc5646_locale")
    query.select("commit_id, translated, rfc5646_locale, COUNT(*) AS translations_count, SUM(words_count) AS words_count")
  end

  # @param [Collection<Translation>] translation_groups Augmented translation objects. Each is required to
  #   have these fields: `commit_id`, `translated`, `translations_count`, `words_count`, `rfc5646_locale`.
  #
  # @return [Hash<Integer, Hash<Symbol, Hash<Symbol, Integer>>>] all the stats in a hash.
  #   Ex: a specific stat can be accessed by hsh[commit.id][:translations][:new]

  def parse_commit_stats(translation_groups)
    # prep
    commit_id_to_targeted_rfc5646_locales_hsh = {}
    commit_id_to_required_rfc5646_locales_hsh = {}
    results = {}
    @commits.each do |commit|
      commit_id_to_targeted_rfc5646_locales_hsh[commit.id] = commit.project.targeted_rfc5646_locales.keys
      commit_id_to_required_rfc5646_locales_hsh[commit.id] = commit.project.required_rfc5646_locales
      results[commit.id] = { translations: { pending: 0, new: 0 }, words: { pending: 0, new: 0 } }
    end

    # parse
    translation_groups.each do |tg|
      if (@locales.present? && commit_id_to_targeted_rfc5646_locales_hsh[tg.commit_id].include?(tg.rfc5646_locale)) ||
         (@locales.blank?   && commit_id_to_required_rfc5646_locales_hsh[tg.commit_id].include?(tg.rfc5646_locale))
        state = tg.translated? ? :pending : :new
        results[tg.commit_id][:translations][state] += tg.translations_count
        results[tg.commit_id][:words][state] += tg.words_count
      end
    end
    results
  end
end
