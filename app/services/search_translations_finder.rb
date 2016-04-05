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

  attr_reader :form

  def initialize(form)
    @form = form
  end

  def find_translations
    project_id    = form[:project_id]
    query_filter  = form[:query]
    field         = form[:field]
    translator_id = form[:translator_id]

    start_date    = form[:start_date]
    end_date      = form[:end_date]
    target_locales = form[:target_locales] if form[:target_locales].present?
    hidden_keys = form[:hidden_keys] if form[:hidden_keys].present?

    offset = (form[:page] - 1) * SearchController::PER_PAGE
    limit = SearchController::PER_PAGE

    translations_in_es = Translation.search do
      if target_locales
        if target_locales.size > 1
          locale_filters = target_locales.map do |locale|
            {term: {rfc5646_locale: locale.rfc5646}}
          end
          filter :or, *locale_filters
        else
          filter :term, rfc5646_locale: target_locales.map(&:rfc5646)[0]
        end
      end
      size limit
      from offset

      if project_id and project_id > 0
        filter :term, project_id: project_id
      end
      if translator_id and translator_id > 0
        filter :term, translator_id: translator_id
      end

      if start_date
        filter :range, updated_at: { gte: start_date }
      end

      if end_date
        filter :range, updated_at: { lte: end_date }
      end

      if hidden_keys
        filter :term, { hidden_in_search: true }
      else
        # exclude translations whose keys translators want hidden
        filter :term, { hidden_in_search: false }
      end

      if query_filter.present?
        case field
          when 'searchable_source_copy' then
            query { match 'source_copy', query_filter, operator: 'or' }
          else
            query { match 'copy', query_filter, operator: 'or' }
        end
      else
        sort { by :id, 'desc' }
      end
    end

    translations = Translation.where(id: translations_in_es.map(&:id)).includes(key: :project)
    PaginatableObjects.new(translations, translations_in_es, form[:page], limit)
  end
end