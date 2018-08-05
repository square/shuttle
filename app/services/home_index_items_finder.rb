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
require 'paginatable_objects'

class HomeIndexItemsFinder

  attr_reader :user, :form
  include Elasticsearch::DSL

  def initialize(user, form)
    @user = user
    @form = form
  end

  def search_query
    # FILTERS AND SORTING
    status            = form[:filter__status]
    locales           = form[:filter__locales]
    sort_field        = form[:sort__field]
    sort_direction    = form[:sort__direction]
    sha               = form[:commits_filter__sha]
    project_id        = form[:commits_filter__project_id]
    hide_exported     = form[:commits_filter__hide_exported]
    hide_autoimported = form[:commits_filter__hide_autoimported]
    show_only_mine    = form[:commits_filter__show_only_mine]
    hide_duplicates   = form[:commits_filter__hide_duplicates]

    # PAGINATION
    offset = form[:offset]
    limit  = form[:limit]

    # UNCOMPLETED IN SPECIFIC LOCALES
    if locales.present? && (status == 'uncompleted')
      uncompleted_key_ids_in_locales = uncompleted_key_ids_in_locales()
    end

    search {
      query do
        filtered do
          filter do
            bool do
              must { prefix revision: sha } if sha
              must { term project_id: project_id } unless project_id == 'all'
              must { term exported: false } if hide_exported
              must { exists field: :user_id } if hide_autoimported
              must { term user_id: 1 } if show_only_mine
              must { term loading: false }
              must { term duplicate: false } if hide_duplicates

              case status
              when 'uncompleted'
                locales.present? ? must { terms key_ids: uncompleted_key_ids_in_locales } : must { term ready: false }
              when 'completed'
                must { term ready: true }
              when 'hidden'
                # Do nothing as Commit has no such state. We have this to line up with Article since
                # Commit and Article share the same frontend template.
                must { match_all }
              when 'all'
                must { match_all }
              end
            end
          end
        end
      end

      from offset
      size limit
      sort do
        case sort_field
        when 'due'
          by :due_date, order: sort_direction.nil? ? 'asc' : sort_direction
          by :priority, order: 'asc'
          by :created_at, order: 'desc'
        when 'create'
          by :created_at, order: sort_direction.nil? ? 'desc' : sort_direction
          by :priority, order: 'asc'
          by :due_date, order: 'asc'
        else
          by :priority, order: sort_direction.nil? ? 'asc' : sort_direction
          by :due_date, order: 'asc'
          by :created_at, order: 'desc'
        end
      end
    }.to_hash
  end

  def find_commits
    #Search
    commits_in_es = Elasticsearch::Model.search(search_query, Commit).results

    # LOAD
    commits = Commit
                  .where(id: commits_in_es.map(&:id))
                  .includes(:user, project: :slugs)
    PaginatableObjects.new(commits, commits_in_es, form[:page], form[:limit])
  end

  def find_articles
    articles = Article.includes(:project).showing

    # filter by name
    articles = articles.for_name(form[:articles_filter__name]) if form[:articles_filter__name]

    # filter by project
    articles = articles.where(project_id: form[:articles_filter__project_id]) unless form[:articles_filter__project_id] == 'all'

    # filter by status
    case form[:filter__status]
      when 'uncompleted'
        if form[:filter__locales].present?
          articles = articles.joins(:keys).where(keys: { id: uncompleted_key_ids_in_locales }).merge(Section.active).merge(Key.active_in_section) # TODO: this join may become quite expensive. needs to be monitored when articles are in full use.
        else
          articles = articles.not_ready
        end
      when 'completed'
        articles = articles.ready
      when 'hidden'
        articles = Article.includes(:project).hidden
    end

    # sorting
    direction = %w(asc desc).include?(form[:sort__direction]) ? form[:sort__direction] : nil
    order_by = case form[:sort__field]
      when 'due'
        "due_date #{direction || 'asc'}"
      when 'create'
        "created_at #{direction || 'desc'}"
      when 'priority'
        "priority #{direction || 'asc'}"
    end
    articles = articles.order(order_by) if order_by

    articles = articles.page(form[:page]).per(form[:limit]) # limit and offset

    articles.uniq
  end

  def find_assets
    assets = Asset.includes(:project).showing

    # filter by name
    assets = assets.for_name(form[:assets_filter__name]) if form[:assets_filter__name]

    # filter by project
    assets = assets.where(project_id: form[:assets_filter__project_id]) unless form[:assets_filter__project_id] == 'all'

    # filter by status
    case form[:filter__status]
      when 'uncompleted'
        if form[:filter__locales].present?
          assets = assets.joins(:keys).where(keys: { id: uncompleted_key_ids_in_locales })
        else
          assets = assets.not_ready
        end
      when 'completed'
        assets = assets.ready
      when 'hidden'
        assets = Asset.includes(:project).hidden
    end

    # sorting
    direction = %w(asc desc).include?(form[:sort__direction]) ? form[:sort__direction] : nil
    order_by = case form[:sort__field]
      when 'due'
        "due_date #{direction || 'asc'}"
      when 'create'
        "created_at #{direction || 'desc'}"
      when 'priority'
        "priority #{direction || 'asc'}"
    end
    assets = assets.order(order_by) if order_by

    assets = assets.page(form[:page]).per(form[:limit]) # limit and offset

    assets.uniq
  end

  def find_groups
    groups = Group.includes(:project).showing.joins(:articles)

    # filter by name
    groups = groups.where("groups.name like '%#{form[:groups_filter__name]}%'") if form[:groups_filter__name]

    # filter by project
    groups = groups.where(project_id: form[:groups_filter__project_id]) unless form[:groups_filter__project_id] == 'all'

    # filter by status
    case form[:filter__status]
    when 'uncompleted'
      if form[:filter__locales].present?
        groups = groups.joins(articles: :keys).where(keys: { id: uncompleted_key_ids_in_locales }).merge(Section.active).merge(Key.active_in_section)
      else
        groups = groups.not_ready
      end
    when 'completed'
      groups = groups.ready
    when 'hidden'
      groups = Group.includes(:project).hidden
    end

    # sorting
    direction = %w(asc desc).include?(form[:sort__direction]) ? form[:sort__direction] : nil
    order_by = case form[:sort__field]
               when 'due'
                 "due_date #{direction || 'asc'}"
               when 'create'
                 "created_at #{direction || 'desc'}"
               when 'priority'
                 "priority #{direction || 'asc'}"
               end
    groups = groups.order(order_by) if order_by

    groups = groups.page(form[:page]).per(form[:limit]) # limit and offset

    groups.uniq
  end

  private

  def uncompleted_key_ids_in_locales
    @_uncompleted_key_ids_in_locales ||= Translation.not_base.not_approved.in_locale(*@form[:filter__locales]).select(:key_id).uniq.pluck(:key_id)
  end
end
