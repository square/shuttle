class StashWebhookHelper
  include Rails.application.routes.url_helpers

  def ping(commit, purged = false)
    if commit.project.stash_webhook_url.present?
      stash_webhook_url = "#{commit.project.stash_webhook_url.sub(/\/$/, '')}/#{commit.revision}"
      post_parameters = {
          key: 'SHUTTLE',
          name: "SHUTTLE-#{commit.revision[0..6]}",
          url: project_commit_url(commit.project,
                                  commit,
                                  host: Shuttle::Configuration.worker.default_url_options.host,
                                  port: Shuttle::Configuration.worker.default_url_options['port'],
                                  protocol: Shuttle::Configuration.worker.default_url_options['protocol'] || 'http'),
      }
      headers = { 'Content-Type' => 'application/json',
                  'Accept' => 'application/json' }
      auth = {
          username: Shuttle::Configuration.stash.username,
          password: Shuttle::Configuration.stash.password,
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

      if purged
        post_parameters[:description] = 'Commit has been purged from Shuttle.  Please resubmit.'
        post_parameters[:url] = root_url(
            host: Shuttle::Configuration.worker.default_url_options.host,
            port: Shuttle::Configuration.worker.default_url_options['port'],
            protocol: Shuttle::Configuration.worker.default_url_options['protocol'] || 'http'
        )
      end

      HTTParty.post(stash_webhook_url, { timeout: 5,
                                         body: post_parameters.to_json,
                                         headers: headers,
                                         basic_auth: auth })
    end
  end
end