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

  def initialize(user, form)
    @user = user
    @form = form
  end

  def search_query
    commits = CommitsIndex.filter(bool: {must: [
                                                   form[:commits_filter__sha] ? {prefix: {revision: form[:commits_filter__sha]}} : nil,
                                                   form[:commits_filter__project_id] == 'all' ? nil : {term: {project_id: form[:commits_filter__project_id]}},
                                                   form[:commits_filter__hide_exported] ? {term: {exported: false}} : nil,
                                                   form[:commits_filter__hide_autoimported] ? {exists: {field: :user_id}} : nil,
                                                   form[:commits_filter__show_only_mine] ? {term: {user_id: 1}} : nil,
                                                   {term: {loading: false}},
                                                   form[:commits_filter__hide_duplicates] ? {term: {duplicate: :false}} : nil,
                                                   (case form[:filter__status]
                                                      when 'uncompleted'
                                                        if form[:filter__locales].present?
                                                          {terms: {key_ids: uncompleted_key_ids_in_locales}}
                                                        else
                                                          {term: {ready: false}}
                                                        end
                                                      when 'completed'
                                                        {term: {ready: true}}
                                                      when 'hidden'
                                                        # Do nothing as Commit has no such state. We have this to line up with Article since
                                                        # Commit and Article share the same frontend template.
                                                        nil
                                                      when 'all'
                                                        nil
                                                   end)
                                               ].compact}).
        offset(form[:offset]).limit(form[:limit])

    commits = case form[:sort__field]
                when 'due'
                  commits.order(due_date:   (form[:sort__direction].nil? ? 'asc' : form[:sort__direction]),
                                priority:   'asc',
                                created_at: 'desc')
                when 'create'
                  commits.order(created_at: (form[:sort__direction].nil? ? 'desc' : form[:sort__direction]),
                                priority:   'asc',
                                due_date:   'asc')
                else
                  commits.order(priority:   (form[:sort__direction].nil? ? 'asc' : form[:sort__direction]),
                                due_date:   'asc',
                                created_at: 'desc')
              end

    return commits
  end

  def find_commits
    commits = search_query.load(scope: -> { includes(:user, project: :slugs) })
    PaginatableObjects.new(commits, form[:page], form[:limit])
  end

  def find_articles
    articles = Article.includes(:project, :groups).showing

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
        "last_import_requested_at #{direction || 'desc'}"
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
    assets = assets.where(name: form[:assets_filter__name]) if form[:assets_filter__name]

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
    groups = Group.includes(:project, :articles).showing.joins(:articles)

    # filter by name
    groups = groups.where("groups.display_name like '%#{form[:groups_filter__name]}%'") if form[:groups_filter__name]

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
                 "groups.due_date #{direction || 'asc'}"
               when 'create'
                 "groups.created_at #{direction || 'desc'}"
               when 'priority'
                 "groups.priority #{direction || 'asc'}"
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
