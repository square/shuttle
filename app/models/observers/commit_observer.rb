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

# This observer on the {Commit} model...
#
# 1. Checks if a webhook should be fired, and enqueues the appropriate job if so.

class CommitObserver < ActiveRecord::Observer
  def after_update(commit)
    ping_webhook(commit)
  end

  private
  def ping_webhook(commit)
    return unless commit.ready_changed? && commit.ready?
    WebhookPinger.perform_once commit.id
  end
end
