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

class ScreenshotMailer < ActionMailer::Base
  default from: Shuttle::Configuration.app.mailer.from

  # Notifies all of the translators on the translators' mailing list that there is a new commit
  # that has finished loading. CC's the creator of the commit.
  #
  # @param [Commit] commit The commit that has finished loading.
  # @return [Mail::Message] The email to be delivered.

  def request_screenshot(commit, user)
    @commit = commit
    @project = commit.project
    @user = user

    mail to: commit_requesters(@commit),
         cc: @user.email,
         subject: t('mailer.screenshot.request_screenshot.subject', sha: @commit.revision_prefix)
  end

  private

  # Notifies all of the translators on the translators' mailing list that there is a new commit
  # that has finished loading. CC's the creator of the commit.
  #
  # @param [Commit] commit The commit that
  # @return [Mail::Message] The email to be delivered.

  def commit_requesters(commit)
    [commit.user.try(:email), commit.author_email].compact.uniq
  end
end
