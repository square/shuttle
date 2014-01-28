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
  PER_PAGE = 30

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
    @status = params[:status]
    unless %w(uncompleted completed all).include?(@status)
      @status = 'uncompleted'
    end
    status = @status

    limit    = params.fetch(:limit, PER_PAGE).to_i
    exported = params[:exported] == 'true'

    # Filter by project
    projects = if params[:project_id] == 'my-locales'
                 Project.scoped.to_a.select do |project|
                   (project.targeted_locales & current_user.approved_locales).any?
                 end
               else
                 [Project.find_by_id(params[:project_id])].compact
               end

    # Filter by SHA
    sha      = params[:sha].presence
    sha = nil unless sha =~ /^[0-9A-F]+$/i
    @sha = sha

    # Filter by user
    params[:email] ||= current_user.email if current_user.monitor? && !current_user.admin?
    user = if params[:email].present?
             User.find_by_email(params[:email])
           else
             nil
           end

    sort_order = params[:sort]
    direction = params[:direction]

    @commits = Commit.search(load: {include: [:user, project: :slugs]}) do
      filter :prefix, revision: sha if sha
      filter :term, project_id: projects.map(&:id) if projects.any?
      filter :term, user_id: user.id if user
      filter :term, exported: false unless exported
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

    @locales = if params[:locales].present?
                 params[:locales].split(',').map { |l| Locale.from_rfc5646 l }.compact
               else
                 []
               end
  end
end
