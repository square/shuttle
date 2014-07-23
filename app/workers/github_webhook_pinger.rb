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

# After a {Commit}'s has been marked as "ready", we need to let external
# services know. Looks up the webhook URL for the {Project} and perform an HTTP
# post with the commit information.

class GithubWebhookPinger
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit.

  def perform(commit_id)
    commit = Commit.find(commit_id)
    raise Project::NotLinkedToAGitRepositoryError unless commit.project.git?

    if commit.project.github_webhook_url.present?
      post_parameters = {commit_revision: commit.revision, project_name: commit.project.name, ready: commit.ready?}
      HTTParty.post(commit.project.github_webhook_url, {timeout: 5, body: post_parameters })
    end
  end

  include SidekiqLocking
end
