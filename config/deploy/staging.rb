set :stage, :staging
set :rails_env, :staging

DEV_WEB_BOXES    = (1..1).map { |i| "square@shuttle-web-dev-a-#{i.to_s.rjust(2, '0')}.sqcorp.co" }
DEV_WORKER_BOXES = (1..1).map { |i| "square@shuttle-worker-dev-a-#{i.to_s.rjust(2, '0')}.sqcorp.co" }

role :app, DEV_WEB_BOXES + DEV_WORKER_BOXES
role :web, DEV_WEB_BOXES
role :db, DEV_WEB_BOXES.first
role :sidekiq, DEV_WORKER_BOXES
set :sidekiq_roles, [:sidekiq]
role :primary_cron, DEV_WORKER_BOXES.first

append :linked_files,
       'config/environments/staging/credentials.yml',
       'config/environments/staging/paperclip.yml'
