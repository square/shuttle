class LocaleProjectsShowForm
  attr_reader :form

  def initialize(form)
    @form = process_params(form)
  end

  def process_params(form)
    project = Project.find_from_slug!(form[:id])
    processed = {}
    processed[:include_translated] = form[:include_translated].parse_bool
    processed[:include_approved]   = form[:include_approved].parse_bool
    processed[:include_new]        = form[:include_new].parse_bool
    processed[:include_block_tags] = form[:include_block_tags].parse_bool
    unless processed[:include_translated] || processed[:include_approved] || processed[:include_new]
      processed[:include_translated] = processed[:include_new] = true
      processed[:include_approved] = true if form[:group]
    end
    processed[:edit_approved] = form[:edit_approved]

    processed[:page]       = form.fetch(:page, 1).to_i
    processed[:query_filter] = form[:filter]
    processed[:commit] = form[:commit]
    processed[:asset_id] = form[:asset_id]
    processed[:translation_ids_in_assest] = project.assets.where(id: form[:asset_id]).first.try(:translations).try(:pluck, :id)
    processed[:translation_ids_in_commit] = project.commits.for_revision(form[:commit]).first.try(:translations).try(:pluck, :id)
    processed[:article_id]  =
      if form[:article_id].present?
        project.articles.find_by_id(form[:article_id]).try(:id)
      elsif form[:article_name].present?
        project.articles.find_by_name(form[:article_name]).try(:id)
      end
    processed[:section_id]  = project.sections.find_by_id(form[:section_id]).try(:id)
    processed[:locale]       = if form[:locale_id]
                                 Locale.from_rfc5646(form[:locale_id])
                               else
                                 nil
                               end
    processed[:project_id]   = project.id
    processed[:project]      = project

    processed[:filter_source] = form[:filter_source]

    if form[:group]
      processed[:group] = form[:group]
      processed[:translation_ids_in_commit] = Group.where(name: form[:group]).includes({articles: :translations}).map(&:articles).flatten.map(&:translations).flatten.map(&:id)
    end

    processed
  end

  def [](k)
    form[k]
  end
end
