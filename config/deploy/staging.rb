set :stage, :staging
set :rails_env, :staging

single_server = "user@shuttle-staging.example.com"

role :app,          [single_server]
role :web,          [single_server]
role :db,           [single_server]
role :sidekiq,      [single_server]
role :primary_cron, [single_server]

ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

set :linked_files, fetch(:linked_files, []).push('config/environments/staging/app.yml',
                                                 'config/environments/staging/paperclip.yml')
