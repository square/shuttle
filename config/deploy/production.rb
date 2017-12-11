set :stage, :production

WEB_BOXES    = (1..2).map { |i| "square@shuttle-web-a-#{i.to_s.rjust(2, '0')}.corp.squareup.com" }
WORKER_BOXES = (1..2).map { |i| "square@shuttle-worker-a-#{i.to_s.rjust(2, '0')}.corp.squareup.com" }

role :app, WEB_BOXES + WORKER_BOXES
role :web, WEB_BOXES
role :db, WEB_BOXES.first
role :sidekiq, WORKER_BOXES
set :sidekiq_roles, [:sidekiq]
role :primary_cron, WORKER_BOXES.first

set :branch, 'deployable'

append :linked_files,
       'config/environments/production/credentials.yml',
       'config/environments/production/paperclip.yml',
       'config/environments/production/sentry.yml'
