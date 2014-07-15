set :stage, :staging
set :rails_env, :staging

role :app, %w{square@shuttle-stage-a-01.corp.squareup.com}
role :web, %w{square@shuttle-stage-a-01.corp.squareup.com}
role :db, %w{square@shuttle-stage-a-01.corp.squareup.com}
role :sidekiq, %w{square@shuttle-stage-a-01.corp.squareup.com}
role :cron, %w{square@shuttle-stage-a-01.corp.squareup.com}
