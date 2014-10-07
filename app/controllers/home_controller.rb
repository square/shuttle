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

  before_filter :authenticate_user!
  before_filter :translator_required, only: [:translators, :glossary]
  before_filter :reviewer_required, only: :reviewers

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

  def index
    page = Integer(params[:page]) rescue 1
    @offset = (page - 1)*PER_PAGE
    offset  = @offset

    # Filter by status
    @status = if params[:status].present?
                params[:status]
              elsif cookies[:home_status_filter].present?
                cookies[:home_status_filter]
              else
                'uncompleted'
              end

    unless %w(uncompleted completed all).include?(@status)
      @status = 'uncompleted'
    end
    status = @status

    limit    = params.fetch(:limit, PER_PAGE).to_i

    exported = if params[:exported].present?
                 params[:exported] == 'true'
               elsif cookies[:home_email_filter].present?
                 cookies[:home_exported_filter] == 'true'
               else
                 false
               end

    show_autoimport = if params[:show_autoimport].present?
                        params[:show_autoimport] == 'true'
                      elsif cookies[:home_autoimport_filter].present?
                        cookies[:home_autoimport_filter] == 'true'
                      else
                        false
                      end

    case
      when (exported and show_autoimport) then @filters = ''
      when (exported) then @filters = '(Hiding auto-imported commits)'
      when (show_autoimport) then @filters = '(Hiding exported commits)'
      else @filters = '(Hiding exported and auto-imported commits)'
    end

    # Filter by project
    projects = if params[:project_id].present?
                 params[:project_id]
               elsif cookies[:home_project_filter].present?
                 cookies[:home_project_filter]
               else
                 nil
               end

    projects = if projects == 'my-locales'
                 Project.scoped.to_a.select do |project|
                   (project.targeted_locales & current_user.approved_locales).any?
                 end
               else
                 [Project.find_by_id(projects)].compact
               end

    @project = projects.first if projects.length == 1

    # Filter by SHA
    sha = params[:sha].presence
    @sha = sha = (sha =~ /^[0-9A-F]+$/i ? sha.downcase : nil)

    # Filter by user
    # Changed for Jim Kingdon.  Testing feature.  Make it such that all users can see all commits.
    # params[:email] ||= current_user.email if current_user.monitor? && !current_user.admin?
    user =  if params[:email].present?
              User.find_by_email(params[:email])
            elsif cookies[:home_email_filter].present? and cookies[:home_email_filter] != 'false'
              User.find_by_email(cookies[:home_email_filter])
            else
              nil
            end
    @filters = '(Only showing my commits)' if user

    @sort_order = sort_order = params[:sort].present? ? params[:sort] : cookies[:home_sort]
    @direction = direction = params[:direction].present? ? params[:direction] : cookies[:home_direction]

    @locales = locales = if params[:locales].present?
                           params[:locales].split(',').map { |l| Locale.from_rfc5646 l }.compact
                         else
                           []
                         end

    @commits = Commit.search(load: {include: [:user, project: :slugs]}) do
      filter :prefix, revision: sha if sha
      filter :term, project_id: projects.map(&:id) if projects.any?
      filter :term, user_id: user.id if user
      filter :term, exported: false unless exported

      filter :exists, field: :user_id unless show_autoimport

      case status
        when 'uncompleted'
          filter :term, ready: false
        when 'completed'
          filter :term, ready: true
      end

      from offset
      size limit

      sort do
        case sort_order
          when 'due'
            by :due_date, (direction.nil? ? 'asc' : direction)
            by :priority, 'asc'
            by :created_at, 'desc'
          when 'create'
            by :created_at, (direction.nil? ? 'desc' : direction)
            by :priority, 'asc'
            by :due_date, 'asc'
          else
            by :priority, (direction.nil? ? 'asc' : direction)
            by :due_date, 'asc'
            by :created_at, 'desc'
        end
      end
    end

    @home_presenter = HomePresenter.new(@commits, @locales)
  end
end
