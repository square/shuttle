set :stage, :staging

role :app, %w{square@baltimore.corp.squareup.com}
role :web, %w{square@baltimore.corp.squareup.com}
role :db, %w{square@baltimore.corp.squareup.com}
role :sidekiq, %w{square@baltimore.corp.squareup.com}
role :cron, %w{square@baltimore.corp.squareup.com}
