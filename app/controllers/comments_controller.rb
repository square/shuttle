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

# Controller for working with {Comment Comments}.

class CommentsController < ApplicationController
  before_filter :find_issue

  layout false
  respond_to :js

  # Creates a Comment for an Issue.
  #
  # Routes
  # ------
  #
  # * `POST /issues/:issue_id/comments`
  #
  # Path Parameters
  # ---------------
  #
  # |            |                     |
  # |:-----------|:--------------------|
  # | `issue_id` | The id of an Issue. |
  #
  # Body Parameters
  # ---------------
  #
  # |           |                                           |
  # |:----------|:------------------------------------------|
  # | `comment` | Parameterized hash of Comment attributes. |

  def create
    comment = current_user.comments.build(comment_params)
    issue = comment.issue
    begin
      Comment.transaction do
        comment.save!
        issue.skip_email_notifications = true
        issue.subscribe(current_user)
      end
    rescue ActiveRecord::RecordInvalid
    end

    issue = Issue.includes(comments: :user).find_by_id!(@issue.id)

    render 'issues/update.js.erb', locals: { project: issue.project,
                                             key: issue.key,
                                             translation: issue.translation,
                                             issue: issue,
                                             comment: ( comment.errors.present? ? comment : Comment.new) }
  end

  private

  def find_issue
    @issue = Issue.find_by_id!(params[:issue_id])
  end

  def comment_params
    params.require(:comment).permit(:content).merge(issue: @issue)
  end

end
