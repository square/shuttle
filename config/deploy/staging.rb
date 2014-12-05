set :stage, :staging
set :rails_env, :staging

single_server = "square@shuttle-stage-a-01.corp.squareup.com"

role :app, [single_server]
role :web, [single_server]
role :db, [single_server]
role :sidekiq, [single_server]
role :primary_cron, [single_server]
