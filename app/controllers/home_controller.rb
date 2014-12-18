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

# Contains landing pages appropriate for each of the User roles.

class HomeController < ApplicationController
  # Typical number of commits to show per page.
  PER_PAGE = 20

  # Displays a landing page depending on the current User's role.
  #
  # Routes
  # ------
  #
  # * `GET /`
  #
  # Query Parameters
  # ----------------
  #
  # |              |                                                                                                          |
  # |:-------------|:---------------------------------------------------------------------------------------------------------|
  # | `start_date` | The earliest date of a window to display Commits within (default 2 weeks ago).                           |
  # | `end_date`   | The latest date of a window to display Commits within (default today).                                   |
  # | `status`     | The readiness status of Commits to show: "completed", "uncompleted", or "all" (default depends on role). |
  # | `project_id` | A Project ID to filter by (default all Projects).                                                        |

  before_action :set_homepage_filters_and_sorts, only: :index

  def index
    @commits = find_commits
    @home_index_presenter = HomeIndexPresenter.new(@commits, @homepage_commits_filter__locales)
  end

  private

  def find_commits
    user = current_user

    # FILTERS AND SORTING
    sha               = @homepage_commits_filter__sha
    status            = @homepage_commits_filter__status
    project_id        = @homepage_commits_filter__project_id
    locales           = @homepage_commits_filter__locales
    hide_exported     = @homepage_commits_filter__hide_exported
    hide_autoimported = @homepage_commits_filter__hide_autoimported
    show_only_mine    = @homepage_commits_filter__show_only_mine
    sort_by_field     = @homepage_commits_sort__field
    sort_direction    = @homepage_commits_sort__direction


    # PAGINATION
    page   = Integer(params[:page]) rescue 1
    offset = (page - 1)*PER_PAGE
    limit  = PER_PAGE

    # UNCOMPLETED IN SPECIFIC LOCALES
    if locales.present? && (status == 'uncompleted')
      uncompleted_key_ids_in_locales = uncompleted_key_ids_in_locales(locales)
    end

    # SEARCH
    Commit.search(load: {include: [:user, project: :slugs]}) do
      filter :prefix, revision: sha if sha
      filter :term, project_id: project_id if project_id != 'all'

      filter :term, exported: false if hide_exported
      filter :exists, field: :user_id if hide_autoimported
      filter :term, user_id: user.id if show_only_mine

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
        case sort_by_field
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

  def uncompleted_key_ids_in_locales(locales)
    Translation.not_approved.in_locale(*locales).select(:key_id).uniq.pluck(:key_id)
  end

  def set_homepage_filters_and_sorts
    @filters_summary = []
    set_homepage_commits_filter__sha
    set_homepage_commits_filter__status
    set_homepage_commits_filter__project_id
    set_homepage_commits_filter__locales
    set_homepage_commits_filter__hide_exported
    set_homepage_commits_filter__hide_autoimported
    set_homepage_commits_filter__show_only_mine
    set_homepage_sort__field_and_direction
  end

  def set_homepage_commits_filter__sha
    sha = params[:homepage_commits_filter__sha].presence
    @homepage_commits_filter__sha = (sha =~ /^[0-9A-F]+$/i ? sha.downcase : nil)
  end

  def set_homepage_commits_filter__status
    status = params[:homepage_commits_filter__status].presence || cookies[:homepage_commits_filter__status].presence || 'uncompleted'
    status = 'uncompleted' unless %w(uncompleted completed all).include?(status)
    cookies[:homepage_commits_filter__status] = @homepage_commits_filter__status = status
  end

  def set_homepage_commits_filter__project_id
    @homepage_commits_filter__project_id = cookies[:homepage_commits_filter__project_id] =
        params[:homepage_commits_filter__project_id].presence || cookies[:homepage_commits_filter__project_id].presence || 'all'
  end

  def set_homepage_commits_filter__locales
    rfc5646_locales = params[:homepage_commits_filter__rfc5646_locales] || cookies[:homepage_commits_filter__rfc5646_locales] || ""
    @homepage_commits_filter__locales = rfc5646_locales = rfc5646_locales.split(',').map { |l| Locale.from_rfc5646(l) }.compact
    @homepage_commits_filter__rfc5646_locales = cookies[:homepage_commits_filter__rfc5646_locales] = @homepage_commits_filter__locales.map(&:rfc5646)
  end

  def set_homepage_commits_filter__hide_exported
    @homepage_commits_filter__hide_exported = cookies[:homepage_commits_filter__hide_exported] =
        if params[:homepage_commits_filter__hide_exported].present?
          params[:homepage_commits_filter__hide_exported] == 'true'
        elsif cookies[:homepage_commits_filter__hide_exported].present?
          cookies[:homepage_commits_filter__hide_exported] == 'true'
        else
          false
        end

    @filters_summary << ['Hiding exported'] if @homepage_commits_filter__hide_exported
  end

  def set_homepage_commits_filter__hide_autoimported
    @homepage_commits_filter__hide_autoimported = cookies[:homepage_commits_filter__hide_autoimported] =
        if params[:homepage_commits_filter__hide_autoimported].present?
          params[:homepage_commits_filter__hide_autoimported] == 'true'
        elsif cookies[:homepage_commits_filter__hide_autoimported].present?
          cookies[:homepage_commits_filter__hide_autoimported] == 'true'
        else
          false
        end

    @filters_summary << ['Hiding auto-imported'] if @homepage_commits_filter__hide_autoimported
  end

  def set_homepage_commits_filter__show_only_mine
    @homepage_commits_filter__show_only_mine = cookies[:homepage_commits_filter__show_only_mine] =
        if params[:homepage_commits_filter__show_only_mine].present?
          params[:homepage_commits_filter__show_only_mine] == 'true'
        elsif cookies[:homepage_commits_filter__show_only_mine]
          cookies[:homepage_commits_filter__show_only_mine] == 'true'
        else
          false
        end

    @filters_summary << ['Showing only mine'] if @homepage_commits_filter__show_only_mine
  end

  def set_homepage_sort__field_and_direction
    @homepage_commits_sort__field = cookies[:homepage_commits_sort__field] =
        params[:homepage_commits_sort__field].presence || cookies[:homepage_commits_sort__field].presence

    @homepage_commits_sort__direction = cookies[:homepage_commits_sort__direction] =
        params[:homepage_commits_sort__direction].presence || cookies[:homepage_commits_sort__direction].presence
  end
end
