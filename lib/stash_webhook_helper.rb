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

class StashWebhookHelper
  include Rails.application.routes.url_helpers

  DEFAULT_NUM_TIMES = 5
  DEFAULT_WAIT_TIME = 3

  def ping(commit, opts = {})
    raise Project::NotLinkedToAGitRepositoryError unless commit.project.git?
    num_pings = opts[:num_times] || DEFAULT_NUM_TIMES

    if ping_stash_webhook?(commit)
      # Pretty awful but there's no way we can verify that Stash decided to ignore us
      # Other projects do it this way as well
      num_pings.times do
        HTTParty.post(webhook_url(commit), {timeout: 5,
                                            body: webhook_post_parameters(commit, opts),
                                            headers: webhook_header_parameters,
                                            basic_auth: webhook_auth_parameters})
        Kernel.sleep(DEFAULT_WAIT_TIME)
      end
    end
  end

  private

  def ping_stash_webhook?(commit)
    commit.project.stash_webhook_url.present?
  end

  def webhook_url(commit)
    "#{commit.project.stash_webhook_url.sub(/\/$/, '')}/#{commit.revision}"
  end

  def webhook_post_parameters(commit, opts={})
    post_parameters = {
      key: 'SHUTTLE',
      name: "SHUTTLE-#{commit.revision_prefix}",
      url: project_commit_url(commit.project,
                              commit,
                              host: Shuttle::Configuration.app.default_url_options.host,
                              port: Shuttle::Configuration.app.default_url_options['port'],
                              protocol: Shuttle::Configuration.app.default_url_options['protocol'] || 'http'),
    }.merge(current_commit_state(commit))

    if opts[:purged]
      post_parameters[:description] = 'Commit has been purged from Shuttle.  Please resubmit.'
      post_parameters[:url] = root_url(
        host: Shuttle::Configuration.app.default_url_options.host,
        port: Shuttle::Configuration.app.default_url_options['port'],
        protocol: Shuttle::Configuration.app.default_url_options['protocol'] || 'http'
      )
    end
    post_parameters.to_json
  end

  def webhook_auth_parameters
    {username: Shuttle::Configuration.stash.username, password: Shuttle::Configuration.stash.password}
  end

  def webhook_header_parameters
    {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
  end

  def current_commit_state(commit)
    case
      when commit.reload.ready?
        {state: 'SUCCESSFUL', description: 'Translations completed', }
      when commit.loading?
        {state: 'INPROGRESS', description: 'Currently loading', }
      else
        {state: 'INPROGRESS', description: 'Currently translating', }
    end
  end
end
