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

# This observer on the {Commit} model...
#
# 1. Checks if a webhook should be fired, and enqueues the appropriate job if so.
# 2. Checks if the build status should be updated, and enqueues the appropriate job if so.
# 3. Sends an email to the translators alerting them of the new commit, if it has finished loading.

class CommitObserver < ActiveRecord::Observer
  def after_commit(commit)
    ping_stash_webhook(commit)
  end

  def after_commit_on_update(commit)
    ping_github_webhook(commit)
    send_emails(commit)
  end

  private

  def ping_github_webhook(commit)
    if commit.project.git? && commit.project.github_webhook_url && just_became_ready?(commit)
      GithubWebhookPinger.perform_once(commit.id)
    end
  end

  def ping_stash_webhook(commit)
    if commit.project.git? && commit.project.stash_webhook_url && [:id, :ready, :loading].any? { |field| commit.previous_changes.include?(field) }
      StashWebhookPinger.perform_once commit.id
    end
  end

  def send_emails(commit)
    if just_finished_loading?(commit)
      if commit.errored_during_import?
        CommitMailer.notify_submitter_of_import_errors(commit).deliver
      else
        # This code assumes that recalculate_ready! was run on all of commit's keys
        CommitMailer.notify_translators(commit).deliver unless commit.keys_are_ready?
      end
    end

    if just_became_ready?(commit)
      CommitMailer.notify_translation_finished(commit).deliver
    end
  end

  # This should be called in after_commit hooks only because it checks previous_changes hash instead of changes hash.
  def just_became_ready?(commit)
    commit.previous_changes.include?(:ready) && commit.ready?
  end

  # This should be called in after_commit hooks only because it checks previous_changes hash instead of changes hash.
  def just_finished_loading?(commit)
    commit.previous_changes.include?(:loading) && !commit.loading?
  end
end
