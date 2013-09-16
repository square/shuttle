set :application, 'shuttle'
set :repository, 'git@git.squareup.com:intl/shuttle.git'
set :rvm_ruby_string, '1.9.3-p448@shuttle'
set :rvm_type, :system

set :scm, :git

role :web, 'ironweed.corp.squareup.com'
role :app, 'ironweed.corp.squareup.com', 'ginger.corp.squareup.com'
role :db, 'ironweed.corp.squareup.com', primary: true

set :user, 'square'
set :runner, 'square'

set :deploy_to, File.join('', 'app', application)
set :deploy_via, :copy
set :copy_cache, true

default_run_options[:pty] = true

require 'bundler/capistrano'
gem 'rvm-capistrano'
require 'rvm/capistrano'
load 'deploy/assets'
set :whenever_command, 'bundle exec whenever'
require 'whenever/capistrano'

namespace :deploy do
  task :stop, roles: :app do
    # noop
  end

  task :start, roles: :app do
    # noop
  end

  task :restart, roles: :app, except: {no_release: true} do
    run "touch #{release_path}/tmp/restart.txt"
  end
end

before 'deploy:setup', 'rvm:install_ruby'
before 'deploy:setup', 'rvm:create_gemset'

namespace :repos do
  task :create do
    run "mkdir -p #{shared_path}/tmp/repos"
  end

  task :symlink do
    run "rm -Rf #{release_path}/tmp/repos"
    run "ln -s #{shared_path}/tmp/repos #{release_path}/tmp/repos"
  end
end
after 'deploy:setup', 'repos:create'
before 'deploy:assets:precompile', 'repos:symlink'

require 'sidekiq/capistrano'

namespace :squash do
  task :notify do
    run "cd #{release_path} && bin/rails runner -e #{rails_env} 'Squash::Ruby.notify_deploy #{rails_env.inspect}, #{current_revision.inspect}, #{Socket.gethostname.inspect}'", once: true
  end
end
after 'deploy:restart', 'squash:notify'

namespace :secret do
  task :symlink do
    run "rm -Rf #{release_path}/data/secret_token"
    run "ln -s #{shared_path}/secret_token #{release_path}/data/secret_token"
  end
end
before 'deploy:assets:precompile', 'secret:symlink'
