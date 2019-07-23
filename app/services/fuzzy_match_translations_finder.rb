# Copyright 2016 Square Inc.
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

class FuzzyMatchTranslationsFinder
  attr_reader :translation

  FUZZY_MATCH_MIN_SCORE = 60
  FUZZY_MATCH_RESULT_SIZE = 5
  ES_SEARCH_BATCH_SIZE = 5

  def initialize(query_filter, translation)
    @query_filter = query_filter
    @translation = translation
  end

  def search_query
    query_params = []
    query_params << { match: { source_copy: { query: @query_filter, operator: 'or' } } }

    filter_params = []
    filter_params << { term: { approved: true } }
    filter_params << { terms: { rfc5646_locale: translation.locale.fallbacks.map(&:rfc5646) } }
    filter_params << { term: { hidden_in_search: false } }

    query = TranslationsIndex.query(query_params).filter(filter_params)
    query = query.limit(ES_SEARCH_BATCH_SIZE)

    return query
  end

  def find_fuzzy_match
    translations = search_query.load(scope: -> { includes(key: :project) }).objects
    translations = translations.reject { |t| @query_filter.similar(t.source_copy) < FUZZY_MATCH_MIN_SCORE }
    translations = translations.sort { |a, b| @query_filter.similar(b.source_copy) <=> @query_filter.similar(a.source_copy) }
    translations.first(FUZZY_MATCH_RESULT_SIZE).map { |t| Translation.find(t.id) }
  end

  def top_fuzzy_match_percentage
    translations = find_fuzzy_match
    translations = translations.map do |tran|
      {
          match_percentage: @translation.source_copy.similar(tran.source_copy),
      }
    end.reject { |t| t[:match_percentage] < FUZZY_MATCH_MIN_SCORE }
    translations.sort! { |a, b| b[:match_percentage] <=> a[:match_percentage] }
    translations.any? ? translations.first[:match_percentage] : 0.0
  end
end
