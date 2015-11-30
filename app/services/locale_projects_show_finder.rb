class LocaleProjectsShowFinder
  attr_reader :form
  PER_PAGE = 50


  def initialize(form)
    @form = form
  end

  def find_translations
    include_translated = form[:include_translated]
    include_approved   = form[:include_approved]
    include_new        = form[:include_new]

    page       = form[:page]
    query_filter = form[:query_filter]
    translation_ids_in_commit = form[:translation_ids_in_commit]
    article_id   = form[:article_id]
    section_id   = form[:section_id]
    locale       = form[:locale]
    project_id   = form[:project_id]
    project      = form[:project]
    filter_source = form[:filter_source]

    translations = Translation.search(load: {include: [{key: [:project, :translations, :section, { article: :project} ]}, :locale_associations]}) do
      filter :term, project_id: project_id
      filter :term, rfc5646_locale: locale.rfc5646 if locale
      filter :ids, values: translation_ids_in_commit if translation_ids_in_commit
      filter :term, article_id: article_id if article_id.present?
      filter :term, section_id: section_id if section_id.present?
      filter :term, section_active: true if project.not_git?        # active sections
      filter :exists, field: :index_in_section if project.not_git?  # active keys in sections

      if query_filter.present?
        if filter_source == 'source'
          query { match 'source_copy', query_filter, operator: 'and' }
        elsif filter_source == 'translated'
          query { match 'copy', query_filter, operator: 'and' }
        end
      end

      if include_translated && include_approved && include_new
        # include everything
      elsif include_translated && include_approved
        filter :term, translated: 1
      elsif include_translated && include_new
        filter :or, [
                      {missing: {field: 'approved', existence: true, null_value: true}},
                      {term: {approved: 0}}]
      elsif include_approved && include_new
        filter :or, [
                      {term: {approved: 1}},
                      {term: {translated: 0}}]
      elsif include_approved
        filter :term, {approved: 1}
      elsif include_new
        filter :or, [
                      {term: {translated: 0}},
                      {term: {approved: 0}}]
      elsif include_translated
        filter :and,
               {missing: {field: 'approved', existence: true, null_value: true}},
               {term: {translated: 1}}
      else
        # include nothing
        throw :include_nothing
      end

      from (page - 1) * PER_PAGE
      size PER_PAGE

      if project.not_git?
        sort do
          by :section_id, 'asc'
          by :index_in_section, 'asc'
        end
      end
    end
    translations ||= []
    translations
  end
end