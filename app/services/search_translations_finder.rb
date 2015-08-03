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

    offset = (form[:page] - 1) * SearchController::PER_PAGE
    limit = SearchController::PER_PAGE

    Translation.search(load: {include: {key: :project}}) do
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
  end
end