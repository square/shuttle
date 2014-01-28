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
# 2. Sends an email to the translators alerting them of the new commit, if it has finished loading.

class CommitObserver < ActiveRecord::Observer
  def after_update(commit)
    ping_webhook(commit)
    send_email(commit)
  end

  private
  def ping_webhook(commit)
    return unless commit.ready_changed? && commit.ready?
    WebhookPinger.perform_once commit.id
  end

  def send_email(commit)
    if commit.loading_was == true && commit.loading == false
      CommitMailer.notify_translators(commit).deliver
    end
    if commit.ready_was == false && commit.ready == true && commit.loading == false
      CommitMailer.notify_translation_finished(commit).deliver
    end
  end
end
