set :application, 'shuttle'
set :repo_url, 'https://stash.corp.squareup.com/scm/intl/shuttle.git'

set :branch, 'deployable'

set :deploy_to, "/app/#{fetch :application}"

set :linked_files, %w{  config/database.yml
                        config/environments/staging/paperclip.yml
                        config/environments/production/paperclip.yml
                        config/environments/production/stash.yml
                        data/secret_token
                        tmp/sidekiq.pid  }
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle tmp/repos tmp/working_repos}

set :rvm_type, :system
set :rvm_ruby_version, "2.0.0-p576@#{fetch :application}"

set :whenever_roles, :cron
set :sidekiq_role, :sidekiq

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :finishing, 'deploy:cleanup'
end

before 'deploy:publishing', 'squash:write_revision'
