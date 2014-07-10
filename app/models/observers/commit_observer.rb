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
  def before_update(commit)
    handle_import_errors(commit)
  end

  def after_commit(commit)
    ping_stash_webhook(commit)
  end

  def after_commit_on_update(commit)
    ping_github_webhook(commit)
  end

  def after_update(commit)
    send_email(commit)
    cleanup_import_errors(commit)
  end

  private

  def ping_github_webhook(commit)
    if commit.project.github_webhook_url && commit.previous_changes.include?(:ready) && commit.ready? # if it just became ready
      GithubWebhookPinger.perform_once(commit.id)
    end
  end

  def ping_stash_webhook(commit)
    if commit.project.stash_webhook_url && [:id, :ready, :loading].any? { |field| commit.previous_changes.include?(field) }
      StashWebhookPinger.perform_once commit.id
    end
  end

  def send_email(commit)
    if commit.loading_was == true && commit.loading == false && !commit.completed_at && commit.import_errors.blank? && commit.import_errors_in_redis.blank?
      CommitMailer.notify_translators(commit).deliver
    end
    if commit.ready_was == false && commit.ready == true && commit.loading == false
      CommitMailer.notify_translation_finished(commit).deliver
    end
  end

  def handle_import_errors(commit)
    if commit.loading_was == true && commit.loading == false && commit.import_errors_in_redis.present?
      commit.copy_import_errors_from_redis_to_sql_db
      CommitMailer.notify_submitter_of_import_errors(commit).deliver
    end
  end

  def cleanup_import_errors(commit)
    if commit.loading_was == true && commit.loading == false && commit.import_errors.present? && commit.import_errors == commit.import_errors_in_redis
      commit.clear_import_errors_in_redis
    end
  end
end
