set :stage, :staging
set :rails_env, :staging

STAGING_BOXES = %w[square@shuttle-stage-b-01.corp.squareup.com]

role :app, STAGING_BOXES
role :web, STAGING_BOXES
role :db, STAGING_BOXES.first
# sidekiq is currently disabled in staging until bug where staging is
# communicating with production bitbucket is fixed [rob 04/20/18]
role :sidekiq, []
set :sidekiq_roles, []
role :primary_cron, STAGING_BOXES.first

append :linked_files,
       'config/environments/staging/credentials.yml',
       'config/environments/staging/paperclip.yml',
       'config/environments/staging/sentry.yml'
