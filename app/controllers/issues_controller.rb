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

# Controller for working with {Issue Issues}.

class IssuesController < ApplicationController
  before_filter :find_project
  before_filter :find_key
  before_filter :find_translation
  before_filter :find_issue, only: [:update, :resolve, :subscribe, :unsubscribe]

  layout false
  respond_to :js

  # Creates an Issue for a Translation.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/keys/:key_id/translations/:translation_id/issues`
  #
  # Path Parameters
  # ---------------
  #
  # |                  |                                                                    |
  # |:-----------------|:-------------------------------------------------------------------|
  # | `project_id`     | The slug of a Project.                                             |
  # | `key_id`         | The slug of a Key in that project.                                 |
  # | `translation_id` | The locale of a Translation relating to the above project and key. |
  #
  # Body Parameters
  # ---------------
  #
  # |         |                                         |
  # |:--------|:----------------------------------------|
  # | `issue` | Parameterized hash of Issue attributes. |

  def create
    issue = current_user.issues.create(issue_params.merge(translation: @translation))
    issues = @translation.issues.includes(:user, comments: :user).order_default
    render template: 'issues/create.js.erb', locals: {project: @project, key: @key, translation: @translation, issues: issues, issue: issue.errors.present? ? issue : Issue.new_with_defaults, created_issue: issue.errors.present? ? nil : issue }
  end

  # Updates an Issue for a Translation.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/keys/:key_id/translations/:translation_id/issues/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |                  |                                                                    |
  # |:-----------------|:-------------------------------------------------------------------|
  # | `project_id`     | The slug of a Project.                                             |
  # | `key_id`         | The slug of a Key in that project.                                 |
  # | `translation_id` | The locale of a Translation relating to the above project and key. |
  # | `id`             | The id of an Issue.                                                |
  #
  # Body Parameters
  # ---------------
  #
  # |         |                                         |
  # |:--------|:----------------------------------------|
  # | `issue` | Parameterized hash of Issue attributes. |

  def update
    @issue.update(issue_params)
    render 'issues/update.js.erb', locals: {project: @project, key: @key, translation: @translation, issue: @issue }
  end

  # Resolves an Issue by updating its status field.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/keys/:key_id/translations/:translation_id/issues/:id/resolve`
  #
  # Path Parameters
  # ---------------
  #
  # |                  |                                                                    |
  # |:-----------------|:-------------------------------------------------------------------|
  # | `project_id`     | The slug of a Project.                                             |
  # | `key_id`         | The slug of a Key in that project.                                 |
  # | `translation_id` | The locale of a Translation relating to the above project and key. |
  # | `id`             | The id of an Issue.                                                |

  def resolve
    @issue.resolve(current_user)
    render 'issues/update.js.erb', locals: {project: @project, key: @key, translation: @translation, issue: @issue }
  end

  # Subscribes the current user to the Issue.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/keys/:key_id/translations/:translation_id/issues/:id/subscribe`
  #
  # Path Parameters
  # ---------------
  #
  # |                  |                                                                    |
  # |:-----------------|:-------------------------------------------------------------------|
  # | `project_id`     | The slug of a Project.                                             |
  # | `key_id`         | The slug of a Key in that project.                                 |
  # | `translation_id` | The locale of a Translation relating to the above project and key. |
  # | `id`             | The id of an Issue.                                                |

  def subscribe
    @issue.skip_email_notifications = true
    @issue.subscribe(current_user)
    render 'issues/update.js.erb', locals: {project: @project, key: @key, translation: @translation, issue: @issue }
  end

  # Unsubscribes the current user to the Issue.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/keys/:key_id/translations/:translation_id/issues/:id/unsubscribe`
  #
  # Path Parameters
  # ---------------
  #
  # |                  |                                                                    |
  # |:-----------------|:-------------------------------------------------------------------|
  # | `project_id`     | The slug of a Project.                                             |
  # | `key_id`         | The slug of a Key in that project.                                 |
  # | `translation_id` | The locale of a Translation relating to the above project and key. |
  # | `id`             | The id of an Issue.                                                |

  def unsubscribe
    @issue.skip_email_notifications = true
    @issue.unsubscribe(current_user)
    render 'issues/update.js.erb', locals: {project: @project, key: @key, translation: @translation, issue: @issue }
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:project_id])
  end

  def find_key
    @key = @project.keys.find_by_id!(params[:key_id])
  end

  def find_translation
    @translation = @key.translations.where(rfc5646_locale: params[:translation_id]).first!
  end

  def find_issue
    @issue = @translation.issues.includes(comments: :user).find_by_id!(params[:id])
  end

  def issue_params
    params.require(:issue).permit(:summary, :priority, :kind, :description, :status, :subscribed_emails).merge(updater_id: current_user.id)
  end
end
