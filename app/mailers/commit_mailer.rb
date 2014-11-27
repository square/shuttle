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

# Sends emails related to commits.

class CommitMailer < ActionMailer::Base
  default from: Shuttle::Configuration.app.mailer.from

  # Notifies all of the translators on the translators' mailing list that there is a new commit
  # that has finished loading. CC's the creator of the commit.
  #
  # @param [Commit] commit The commit that has finished loading.
  # @return [Mail::Message] The email to be delivered.

  def notify_translators(commit)
    @commit = commit

    mail to:      Shuttle::Configuration.app.mailer.translators_list,
         subject: t('mailer.commit.notify_translators.subject'),
         cc:      @commit.user.try!(:email)
  end

  # Notifies the user who submitted the Commit that the translators have
  # finished translating. An email will only be sent if the Commit has a User
  # associated with it.
  #
  # @param [Commit] commit The Commit that has been translated.
  # @return [Mail::Message] The email to be delivered.

  def notify_translation_finished(commit)
    @commit = commit
    if @commit.user.try!(:email)
      mail to: @commit.user.email, subject: t('mailer.commit.notify_translation_finished.subject')
    end
  end

  # Notifies the user who submitted the Commit that error(s) occured during import.
  # An email will only be sent if the Commit has a User associated with it.
  #
  # @param [Commit] commit The Commit that has been imported.
  # @return [Mail::Message] The email to be delivered.

  def notify_submitter_of_import_errors(commit)
    @commit = commit
    submitter_emails = [@commit.author_email, @commit.user.try!(:email)].compact.uniq
    if submitter_emails.present? && @commit.import_errors.present?
      mail to: submitter_emails, subject: t('mailer.commit.notify_submitter_of_import_errors.subject')
    end
  end

  # Notifies the user of a SHA which errored in the CommitCreator worker.
  # An email will only be sent if the options hash a user_id field.
  #
  # @param [Fixnum] user_id The ID of the submitter.
  # @param [Fixnum] project_id The ID of a Project.
  # @param [String] sha The SHA of the commit to that failed in CommitCreator
  # @param [StandardError] err The Error that happened.
  #
  # @return [Mail::Message] The email to be delivered.

  def notify_import_errors_in_commit_creator(user_id, project_id, sha, err)
    if user_id && (user = User.find_by_id(user_id))
      @project = Project.find(project_id)
      @err, @sha = err, sha

      mail to: user.email, subject: t('mailer.commit.notify_import_errors_in_commit_creator.subject', sha: @sha)
    end
  end
end
