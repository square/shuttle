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
      num_pings.times do
        params = {
          timeout: 5,
          body: webhook_post_parameters(commit, opts),
          headers: webhook_header_parameters,
          basic_auth: webhook_auth_parameters
        }
        response = HTTParty.post(webhook_url(commit), params)

        # fails with retry on failure.
        unless response.code.between? 200, 299
          message = "[StashWebhookHelper] Failed to ping stash for commit #{commit.id}, revision: #{commit.revision}, code: #{response.code}"
          details = "#{current_commit_state(commit)} - #{response.inspect}"
          Rails.logger.warn("#{message} - #{details}")
          raise message
        end

        Kernel.sleep(DEFAULT_WAIT_TIME)
      end

      # record metric only when the commit is ready
      if commit.ready and commit.approved_at
        ping_stash_time = Time.current - commit.approved_at
        CustomMetricHelper.record_project_ping_stash_time(commit.project.slug, ping_stash_time)
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
      key: "SHUTTLE-#{commit.project.slug}",
      name: "SHUTTLE-#{commit.project.slug}-#{commit.revision_prefix}",
      url: project_commit_url(commit.project,
                              commit,
                              host: Shuttle::Configuration.default_url_options.host,
                              port: Shuttle::Configuration.default_url_options['port'],
                              protocol: Shuttle::Configuration.default_url_options['protocol'] || 'http'),
    }.merge(current_commit_state(commit))

    if opts[:purged]
      post_parameters[:description] = 'Commit has been purged from Shuttle.  Please resubmit.'
      post_parameters[:url] = root_url(
        host: Shuttle::Configuration.default_url_options.host,
        port: Shuttle::Configuration.default_url_options['port'],
        protocol: Shuttle::Configuration.default_url_options['protocol'] || 'http'
      )
    end
    post_parameters.to_json
  end

  def webhook_auth_parameters
    Shuttle::Configuration.credentials[Shuttle::Configuration.webhook_pinger.host].to_h.symbolize_keys
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
