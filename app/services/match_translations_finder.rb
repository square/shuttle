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

class MatchTranslationsFinder
  attr_reader :translation
  include Elasticsearch::DSL

  def initialize(translation)
    @translation = translation
  end

  def search_query(rfc5646, source_copy)
    search {
      query do
        filtered do
          filter do
            bool do
              must { term approved: 1 }
              must { term rfc5646_locale: rfc5646 }
              must { term source_copy: source_copy }
            end
          end
        end
      end
      sort { by :created_at, order: 'desc' }
      size 1
    }.to_hash
  end

  def find_first_match_translation
    source_copy = translation.source_copy
    translation.locale.fallbacks.each do |fallback|
      query = search_query(fallback.rfc5646, source_copy)
      first_matched_translation = Elasticsearch::Model.search(query, Translation).results.first
      return first_matched_translation.to_hash["_source"] if first_matched_translation
    end
    nil
  end
end