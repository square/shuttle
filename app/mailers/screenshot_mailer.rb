class ScreenshotMailer < ActionMailer::Base
  default from: Shuttle::Configuration.mailer.from

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
