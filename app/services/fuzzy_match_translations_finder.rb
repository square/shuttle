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
  include Elasticsearch::DSL

  def initialize(query_filter, translation)
    @query_filter = query_filter
    @translation = translation
  end

  def search_query
    limit = 5
    query_filter = @query_filter
    target_locales = translation.locale.fallbacks.map(&:rfc5646)
    search {
      query do
        filtered do
          query do
            match 'source_copy' do
              query query_filter
              operator 'or'
            end
          end
          filter do
            bool do
              must { term approved: 1 }
              must { terms rfc5646_locale: target_locales }
              must { term hidden_in_search: false }
            end
          end
        end
      end

      size limit
    }.to_hash
  end

  def find_fuzzy_match
    translations_in_es = Elasticsearch::Model.search(search_query, Translation).results
    translations = Translation.where(id: translations_in_es.map(&:id)).includes(key: :project)
    SortingHelper.order_by_elasticsearch_result_order(translations, translations_in_es)
  end

  def top_fuzzy_match_percentage
    translations = find_fuzzy_match
    translations = translations.map do |tran|
      {
          match_percentage: @translation.source_copy.similar(tran.source_copy),
      }
    end.reject { |t| t[:match_percentage] < 70 }
    translations.sort! { |a, b| b[:match_percentage] <=> a[:match_percentage] }
    translations.any? ? translations.first[:match_percentage] : 0.0
  end
end
