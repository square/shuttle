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

# Sends emails related to Comments

class CommentMailer < ActionMailer::Base
  include ActionView::Helpers::TextHelper
  helper CommentsHelper

  default from: Shuttle::Configuration.app.mailer.from

  # Notifies everybody who is associated with this comment that a new comment is created.
  #
  # @param [Comment] comment The comment that is created.
  # @return [Mail::Message] The email to be delivered.

  def comment_created(comment)
    @comment = comment
    return if @comment.issue.subscribed_emails.empty?
    mail to: @comment.issue.subscribed_emails, subject: t('mailer.comment.comment_created.subject', name: @comment.user_name, content: truncate(@comment.content, length: 50, escape: false))
  end
end
