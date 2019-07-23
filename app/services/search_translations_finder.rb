# Copyright 2016 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicabcle law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require 'paginatable_objects'

class SearchTranslationsFinder
  PER_PAGE = 50

  attr_reader :form

  def initialize(form)
    @form = form
  end

  def search_query
    query_params = []
    text_to_search = form[:query]
    if text_to_search.present?
      if form[:field] == 'searchable_source_copy'
        query_params << { match: { source_copy: { query: text_to_search, operator: 'or' } } }
      else
        query_params << { match: { copy: { query: text_to_search, operator: 'or' } } }
      end
    end

    filter_params = []
    filter_params << { term: { rfc5646_locale: form[:target_locales].first.rfc5646} } if form[:target_locales].present? && form[:target_locales].size > 0
    filter_params << { term: { project_id: form[:project_id].to_i } } if form[:project_id].present?
    filter_params << { term: { translator_id: form[:translator_id].to_i } } if form[:translator_id].present?
    filter_params << { term: { reviewer_id: form[:reviewer_id].to_i } } if form[:reviewer_id].present?
    filter_params << { range: { updated_at: { gte: form[:start_date] } } } if form[:start_date].present?
    filter_params << { range: { updated_at: { lte: form[:end_date] } } } if form[:end_date].present?
    filter_params << { term: { hidden_in_search: form[:hidden_keys] || false } }

    query = TranslationsIndex.query(query_params).filter(filter_params)
    query = query.order(id: :desc) if text_to_search.blank?
    query = query.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
    return query
  end

  def page
    form[:page]
  end

  def find_translations
    translations = search_query.load(scope: -> { includes(key: :project) })
    return PaginatableObjects.new(translations, page, PER_PAGE)
  end
end
