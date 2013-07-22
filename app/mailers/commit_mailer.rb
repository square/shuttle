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

# Sends emails related to commits.

class CommitMailer < ActionMailer::Base
  # Sets the default testing mailer host.
  default_url_options.merge! Shuttle::Configuration.mailer.default_url_options.symbolize_keys
  default from: Shuttle::Configuration.mailer.from

  # Notifies all of the translators on the translators' mailing list that there is a new commit
  # that has finished loading.
  #
  # @param [Commit] commit The commit that has finished loading.
  # @return [Mail::Message] The email to be delivered.

  def notify_translators(commit)
    @commit = commit
    mail to: [Shuttle::Configuration.mailer.translators_list, @commit.user.email],
         subject: t('mailer.commit.notify_translators.subject')
  end

  # Notifies the user who sent the commit that the translators have finished translating the commit.
  # An email will only be sent if the commit has a user associated with it, and if that user has an email address stored.
  #
  # @param [Commit] commit The commit that has been translated.
  # @return [Mail::Message] The email to be delivered.
  def notify_translation_finished(commit)
    @commit = commit
    if @commit.user.try!(:email)
      mail to: @commit.user.email, subject: t('mailer.commit.notify_translation_finished.subject')
    end
  end
end
