set :stage, :production

WEB_BOXES    = %w[user@shuttle.example.com]
WORKER_BOXES = %w[user@shuttle.example.com]

role :app, WEB_BOXES + WORKER_BOXES
role :web, WEB_BOXES
role :db, WEB_BOXES.first
role :sidekiq, WORKER_BOXES
role :primary_cron, WORKER_BOXES.first

set :branch, 'deployable'

append :linked_files,
       'config/environments/production/paperclip.yml',
       'config/environments/production/stash.yml'
