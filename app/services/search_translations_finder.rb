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

class SearchTranslationsFinder
  PER_PAGE = 50

  attr_reader :form
  include Elasticsearch::DSL

  def initialize(form)
    @form = form
  end

  def search_query
    project_id = form[:project_id]
    query_filter = form[:query]
    field = form[:field]
    translator_id = form[:translator_id]

    start_date = form[:start_date]
    end_date = form[:end_date]
    if form[:target_locales].present? && form[:target_locales].size > 0
      target_locales = form[:target_locales].first.rfc5646
    end
    hidden_keys = form[:hidden_keys] if form[:hidden_keys].present?

    offset = (page - 1) * PER_PAGE
    limit = PER_PAGE

    search {
      query do
        filtered do
          if query_filter.present?
            query do
              if field == 'searchable_source_copy'
                match 'source_copy' do
                  query query_filter
                  operator 'or'
                end
              else
                match 'copy' do
                  query query_filter
                  operator 'or'
                end
              end
            end
          end

          filter do
            bool do
              must { term rfc5646_locale: target_locales } if target_locales
              must { term project_id: project_id } if project_id && project_id > 0
              must { term translator_id: translator_id } if translator_id && translator_id > 0
              if start_date
                must {
                  range 'updated_at' do
                    gte start_date
                  end
                }
              end
              if end_date
                must {
                  range 'updated_at' do
                    lte end_date
                  end
                }
              end

              hidden_keys ? must { term hidden_in_search: true } : must { term hidden_in_search: false }
            end
          end
        end
      end

      sort { by :id, order: 'desc' } unless query_filter.present?
      size limit
      from offset
    }.to_hash
  end

  def page
    form[:page]
  end

  def find_translations
    limit = PER_PAGE
    translations_in_es = Elasticsearch::Model.search(search_query, Translation).results
    translations = Translation.where(id: translations_in_es.map(&:id)).includes(key: :project)
    PaginatableObjects.new(translations, translations_in_es, page, limit)
  end
end