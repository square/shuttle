set :stage, :staging
set :rails_env, :staging

STAGING_BOXES = %w[user@shuttle-staging.example.com]

role :app, STAGING_BOXES
role :web, STAGING_BOXES
role :db, STAGING_BOXES.first
role :sidekiq, STAGING_BOXES
role :primary_cron, STAGING_BOXES.first

append :linked_files,
       'config/environments/staging/credentials.yml',
       'config/environments/staging/paperclip.yml'
