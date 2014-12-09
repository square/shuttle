set :stage, :staging
set :rails_env, :staging

single_server = "user@shuttle-staging.example.com"

role :app,          [single_server]
role :web,          [single_server]
role :db,           [single_server]
role :sidekiq,      [single_server]
role :primary_cron, [single_server]
