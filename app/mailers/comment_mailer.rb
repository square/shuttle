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
  default from: Shuttle::Configuration.mailer.from

  # Notifies everybody who is associated with this comment that a new comment is created.
  #
  # @param [Comment] comment The comment that is created.
  # @return [Mail::Message] The email to be delivered.

  def comment_created(comment)
    @comment = comment
    @issue = @comment.issue
    @translation = @issue.translation
    @key = @translation.key
    @project = @key.project

    mail to: related_peoples_emails(@comment, @issue, @translation),
         subject: t('mailer.comment.comment_created.subject', name: @comment.user_name, content: truncate(@comment.content, length: 50, escape: false))
  end

  private

  # Finds the emails of people who should be notified about the given comment.
  #
  # @param [Comment] comment
  # @param [Issue] issue
  # @param [Translation] translation
  # @return [Array<String>] Array of emails of people who are associated with this comment.

  def related_peoples_emails(comment, issue, translation)
    last_commit = translation.key.commits.last

    emails = [Shuttle::Configuration.mailer.translators_list,
              comment.user.try!(:email),
              issue.user.try!(:email),
              issue.updater.try!(:email),
              last_commit.try!(:user).try!(:email),
              last_commit.try!(:author_email)] +
        issue.subscribed_emails +
        issue.comments.includes(:user).map { |comment| comment.user.try!(:email) }

    emails.compact.uniq
  end
end
