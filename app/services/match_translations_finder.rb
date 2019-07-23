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

  def initialize(translation)
    @translation = translation
  end

  def search_query(rfc5646, source_copy)
    filter_params = []
    filter_params << { term: { approved: true } }
    filter_params << { term: { rfc5646_locale: rfc5646 } }
    filter_params << { term: { source_copy: source_copy } }

    query = TranslationsIndex.filter(filter_params)
    query = query.order(created_at: :desc)
    query = query.limit(1)

    return query
  end

  def find_first_match_translation
    source_copy = translation.source_copy
    translation.locale.fallbacks.each do |fallback|
      first_matched_translation = search_query(fallback.rfc5646, source_copy).load.objects.first
      return first_matched_translation if first_matched_translation
    end
    return nil
  end
end
