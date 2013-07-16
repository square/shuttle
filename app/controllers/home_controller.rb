# Copyright 2013 Square Inc.
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
    @offset = params[:offset].to_i

    @status = params[:status]
    unless %w(uncompleted completed all).include?(@status)
      @status = case current_user.role
                 when 'translator', 'reviewer' then 'uncompleted'
                 else 'all'
               end
    end

    # Load commits

    @commits = Commit.
        includes(:user, project: :slugs).
        by_priority_and_due_date.
        offset(@offset).
        limit(30)

    # Filter by project

    params[:project_id] ||= 'my-locales' if current_user.approved_locales.any?
    if params[:project_id] == 'my-locales'
      projects = Project.scoped.to_a.select do |project|
        (project.targeted_locales & current_user.approved_locales).any?
      end
      @commits = @commits.where(project_id: projects.map(&:id))
    else
      project_id = params[:project_id].to_i
      if project_id > 0
        @commits = @commits.where(project_id: project_id)
      end
    end

    # Filter by status

    case @status
      when 'uncompleted' then
        @commits = @commits.where("ready IS FALSE OR loading IS TRUE")
      when 'completed' then
        @commits = @commits.where("ready IS TRUE OR loading IS TRUE")
    end

    # Filter by user

    params[:email] ||= current_user.email if current_user.monitor? && !current_user.admin?
    if params[:email].present?
      user = User.find_by_email(params[:email])
      @commits = @commits.where(user_id: user.id) if user
    end

    @locales = if params[:locales].present?
                 params[:locales].split(',').map { |l| Locale.from_rfc5646 l }.compact
               else
                 []
               end

    @newer = @offset >= 30
    @older = @commits.offset(@offset + 30).exists?
  end

  # Displays a landing page appropriate to translators: They can choose the
  # locale they intend to localize for, then view a list of projects with
  # pending localizations in that locale.
  #
  # Routes
  # ------
  #
  # * `GET /translators`

  def translators
  end

  # Displays a landing page appropriate to reviewers: They can choose the
  # locale they intend to review, then view a list of projects with
  # strings pending review in that locale.
  #
  # Routes
  # ------
  #
  # * `GET /reviewers`

  def reviewers
  end

  # Displays a landing page appropriate to administrators: They can view a list
  # of projects and edit their settings.
  #
  # Routes
  # ------
  #
  # * `GET /administrators`

  def administrators
  end

  # Displays a lnading page appropriate to translators: They can view a list of
  # projects and edit their glossary entries.
  #
  # Routes
  # ------
  #
  # * `GET /glossary`

  def glossary
  end
end
