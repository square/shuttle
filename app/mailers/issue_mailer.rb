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

# Sends emails related to issues.

class IssueMailer < ActionMailer::Base
  include ActionView::Helpers::TextHelper
  helper IssuesHelper

  default from: Shuttle::Configuration.app.mailer.from

  # Notifies everybody who is associated with this issue that a new issue is created.
  #
  # @param [Issue] issue The issue that is created.
  # @return [Mail::Message] The email to be delivered.

  def issue_created(issue)
    return if issue.subscribed_emails.empty?
    @issue = issue
    @translation = @issue.translation
    @key = @translation.key
    @project = @key.project

    mail to: @issue.subscribed_emails,
         subject: t('mailer.issue.issue_created.subject', name: @issue.user_name, summary: truncate(@issue.long_summary, length: 50, escape: false))
  end

  # Notifies everybody who is associated with this issue that the issue is updated.
  #
  # @param [Issue] issue The issue that is updated.
  # @return [Mail::Message] The email to be delivered.

  def issue_updated(issue)
    return if issue.subscribed_emails.empty?
    @issue = issue

    @translatable_fields = %w(priority kind status)

    mail to: @issue.subscribed_emails,
         subject: t('mailer.issue.issue_updated.subject', name: @issue.updater.name, summary: truncate(@issue.long_summary, length: 50, escape: false))
  end
end
