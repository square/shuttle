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

# Calculates not-approved Translation stats for Articles and Commits.
# It will calculate translation/word counts for new/pending Translations.

class ArticleAndCommitNotApprovedTranslationStats

  # @param [Array<Commit>]  commits  The {Commit Commits}   for which stats will be calculated.
  # @param [Array<Article>] articles The {Article Articles} for which stats will be calculated.
  # @param [Array<Group>] groups The {Group Groups} for which stats will be calculated.
  # @param [Array<Asset>]   assets The {Asset Assets} for which stats will be calculated.
  # @param [Array<Locale>]  locales  The list of locales in which stats will be calculated.
  #             If blank, targeted locales will be used instead.

  def initialize(commits, articles, groups, assets, locales)
    @commits, @articles, @groups, @assets, @locales = commits, articles, groups, assets, locales

    # memoize
    @_commit_stats ||= parse_stats(@commits, commit_translation_groups_with_stats)
    @_article_stats ||= parse_stats(@articles, article_translation_groups_with_stats(@articles))
    @_group_stats ||= build_group_stats(@groups)
    @_asset_stats ||= parse_stats(@assets, asset_translation_groups_with_stats)
  end

  # Returns the count of pending/new translations/words for a Commit or Article.
  # Ex: `item_stat(commit, :translations, :new)`, `item_stat(commit, :words, :pending)`
  #
  # @param [Commit, Article, Group, Asset] item The {Commit}, {Article}, {Group}, or {Asset} for which stat will be returned.
  # @param [String] type The type for which stat will be returned. Can be :translations or :words
  # @param [String] state The state for which stat will be returned. Can be :new or :pending
  #
  # @return [Fixnum] the value of the stat for the given commit, type or state

  def item_stat(item, type, state)
    stats = if item.is_a?(Commit)
      @_commit_stats
    elsif item.is_a?(Article)
      @_article_stats
    elsif item.is_a?(Group)
      @_group_stats
    elsif item.is_a?(Asset)
      @_asset_stats
    end
    stats[item.id][type][state]
  end

  private

  # Prepares a query which will group Commit translations in a way that we can extract stats from them easily afterwards.
  # Queries for not_approved translations.

  def commit_translation_groups_with_stats
    query = Translation.not_base.not_approved.joins(:commits_keys)
    query = query.where(commits_keys: { commit_id: @commits.map(&:id) })
    query = query.where(translations: { rfc5646_locale: @locales.map(&:rfc5646) }) if @locales.present?
    query = query.group("commit_id, translated, rfc5646_locale")
    query.select("commit_id as item_id, translated, rfc5646_locale, COUNT(*) AS translations_count, SUM(words_count) AS words_count")
  end

  # Prepares a query which will group Article translations in a way that we can extract stats from them easily afterwards.
  # Queries for not_approved translations.

  def article_translation_groups_with_stats(articles)
    query = Translation.not_base.not_approved.joins(key: :section)
    query = query.merge(Section.active).merge(Key.active_in_section) # only care about active Sections and Keys
    query = query.where(sections: { article_id: articles.map(&:id) } )
    query = query.where(translations: { rfc5646_locale: @locales.map(&:rfc5646) }) if @locales.present?
    query = query.group("article_id, translated, rfc5646_locale")
    query.select("article_id as item_id, translated, rfc5646_locale, COUNT(*) AS translations_count, SUM(words_count) AS words_count")
  end

  # Prepares a query which will group Asset translations in a way that we can extract stats from them easily afterwards.
  # Queries for not_approved translations.

  def asset_translation_groups_with_stats
    query = Translation.not_base.not_approved.joins(:assets_keys)
    query = query.where(assets_keys: { asset_id: @assets.map(&:id) } )
    query = query.where(translations: { rfc5646_locale: @locales.map(&:rfc5646) }) if @locales.present?
    query = query.group("asset_id, translated, rfc5646_locale")
    query.select("asset_id as item_id, translated, rfc5646_locale, COUNT(*) AS translations_count, SUM(words_count) AS words_count")
  end

  # Parses stats for Commits and Articles.
  #
  # @param [Array<Commit, Article>] items array of items for which stats will be parsed.
  #   Each item is guaranteed to have an entry in the final hash. If there is no translation_group for an item,
  #   the entry will default to `0` values for each stat.
  # @param [Collection<Translation>] translation_groups Augmented translation objects. Each is required to
  #   have these fields: `item_id`, `translated`, `translations_count`, `words_count`, `rfc5646_locale`.
  #
  # @return [Hash<Integer, Hash<Symbol, Hash<Symbol, Integer>>>] all the stats in a hash.
  #   Ex: a specific stat can be accessed by hsh[item.id][:translations][:new]

  def parse_stats(items, translation_groups)
    # prep
    item_id_to_targeted_rfc5646_locales_hsh = {}
    item_id_to_required_rfc5646_locales_hsh = {}
    results = {}
    items.each do |item|
      item_id_to_targeted_rfc5646_locales_hsh[item.id] = item.targeted_rfc5646_locales.keys
      item_id_to_required_rfc5646_locales_hsh[item.id] = item.required_rfc5646_locales
      results[item.id] = { translations: { pending: 0, new: 0 }, words: { pending: 0, new: 0 } }
    end

    # parse
    translation_groups.each do |tg|
      if (@locales.present? && item_id_to_targeted_rfc5646_locales_hsh[tg.item_id].include?(tg.rfc5646_locale)) ||
         (@locales.blank?   && item_id_to_required_rfc5646_locales_hsh[tg.item_id].include?(tg.rfc5646_locale))
        state = tg.translated? ? :pending : :new
        results[tg.item_id][:translations][state] += tg.translations_count
        results[tg.item_id][:words][state] += tg.words_count
      end
    end
    results
  end

  # Build stats for Groups
  #
  # @param [Array<Group>] array of groups for which will be build.
  #   Each item is guaranteed to have an entry in the final hash. If there is no translation_group for an item,
  #   the entry will default to `0` values for each stat.
  # @return [Hash<Integer, Hash<Symbol, Hash<Symbol, Integer>>>] all the stats in a hash.
  #   Ex: a specific stat can be accessed by hsh[item.id][:translations][:new]

  def build_group_stats(groups)
    # calculate stats for articles in all groups
    articles = groups.map(&:articles).flatten.uniq
    articles_stats = parse_stats(articles, article_translation_groups_with_stats(articles))

    # walks each group and sum stats from its article stats
    groups.each_with_object({}) do |group, result|
      # sums group stats from all of its articles
      result[group.id] = group.articles.each_with_object({}) do |article, group_stats|
        article_stats = articles_stats[article.id]

        # walks through article's stats
        article_stats.each do |type, type_stats|
          group_stats[type] ||= {}

          # sums article's stats to group's stats
          type_stats.each do |state, state_stats|
            group_stats[type][state] ||= 0
            group_stats[type][state] += state_stats
          end
        end
      end
    end
  end
end
