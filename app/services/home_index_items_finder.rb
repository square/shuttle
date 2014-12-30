# Copyright 2014 Square Inc.
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

class HomeIndexItemsFinder

  attr_reader :user, :form

  def initialize(user, form)
    @user = user
    @form = form
  end

  def find_commits
    user = user()

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

    # PAGINATION
    offset = form[:offset]
    limit  = form[:limit]

    # UNCOMPLETED IN SPECIFIC LOCALES
    if locales.present? && (status == 'uncompleted')
      uncompleted_key_ids_in_locales = uncompleted_key_ids_in_locales()
    end

    # SEARCH
    Commit.search(load: {include: [:user, project: :slugs]}) do
      filter :prefix, revision: sha if sha
      filter :term, project_id: project_id unless project_id == 'all'

      filter :term, exported: false if hide_exported
      filter :exists, field: :user_id if hide_autoimported
      filter :term, user_id: user.id if show_only_mine

      # filter by status
      case status
        when 'uncompleted'
          if locales.present?
            filter :terms, key_ids: uncompleted_key_ids_in_locales
          else
            filter :term, ready: false
          end
        when 'completed'
          filter :term, ready: true
      end

      from offset
      size limit

      sort do
        case sort_field
          when 'due'
            by :due_date, (sort_direction.nil? ? 'asc' : sort_direction)
            by :priority, 'asc'
            by :created_at, 'desc'
          when 'create'
            by :created_at, (sort_direction.nil? ? 'desc' : sort_direction)
            by :priority, 'asc'
            by :due_date, 'asc'
          else
            by :priority, (sort_direction.nil? ? 'asc' : sort_direction)
            by :due_date, 'asc'
            by :created_at, 'desc'
        end
      end
    end
  end

  def find_articles
    articles = Article.includes(:project)

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

  private

  def uncompleted_key_ids_in_locales
    @_uncompleted_key_ids_in_locales ||= Translation.not_base.not_approved.in_locale(*@form[:filter__locales]).select(:key_id).uniq.pluck(:key_id)
  end
end
