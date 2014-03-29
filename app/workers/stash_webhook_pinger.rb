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

# After a {Commit}'s status has been changed, we need to ping the build server to
# let it know what the current status of the commit is.  Looks up the
# build status URL for the {Project} and performs an HTTP post with the status information.

class StashWebhookPinger
  include Sidekiq::Worker
  include Rails.application.routes.url_helpers

  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit.

  def perform(commit_id)
    commit = Commit.find(commit_id)
    if commit.project.stash_webhook_url.present?
      stash_webhook_url = "#{commit.project.stash_webhook_url.sub(/\/$/, '')}/#{commit.revision}"
      post_parameters = {
          key: 'SHUTTLE',
          name: "SHUTTLE-#{commit.revision[0..6]}",
          url: project_commit_url(commit.project,
                                  commit,
                                  host: Shuttle::Configuration.worker.default_url_options.host,
                                  port: Shuttle::Configuration.worker.default_url_options['port'],
                                  protocol: Shuttle::Configuration.worker.default_url_options['protocol'] || 'http' ),
      }
      case
        when commit.ready?
          post_parameters.merge!(
              state: 'SUCCESSFUL',
              description: 'Translations completed',
          )
        when commit.loading?
          post_parameters.merge!(
              state: 'INPROGRESS',
              description: 'Currently loading',
          )
        else
          post_parameters.merge!(
              state: 'INPROGRESS',
              description: 'Currently translating',
          )
      end

      HTTParty.post(stash_webhook_url, { timeout: 5, body: post_parameters })
    end
  end

  include SidekiqLocking
end
