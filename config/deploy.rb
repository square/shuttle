# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

set :application, 'shuttle'

set :repo_url, 'https://stash.corp.squareup.com/scm/intl/shuttle.git'
ask(:branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp })

set :deploy_to, "/app/#{fetch :application}"

append :linked_files,
       'config/database.yml',
       'config/secrets.yml'
append :linked_dirs,
       'log',
       'tmp/pids', 'tmp/cache', 'tmp/sockets',
       'tmp/repos', 'tmp/working_repos',
       'vendor/bundle'

set :rvm_type, :system
set :rvm_ruby_version, "2.3.1@#{fetch :application}"

set :runit_timeout, 60
set :whenever_roles, [:app, :primary_cron]

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:web), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end
end

namespace :sidekiq do
  Rake::Task["sidekiq:quiet"].clear_actions
  task :quiet do
    on roles fetch(:sidekiq_roles) do
      within release_path do
        execute :sidekiqctl, 'quiet', release_path.join('tmp/pids/sidekiq-0.pid')
        execute :sidekiqctl, 'quiet', release_path.join('tmp/pids/sidekiq-1.pid')
        execute :sidekiqctl, 'quiet', release_path.join('tmp/pids/sidekiq-2.pid')
      end
    end
  end

  Rake::Task["sidekiq:stop"].clear_actions
  task :stop do
    on roles fetch(:sidekiq_roles) do
      sudo "sv -w #{fetch(:runit_timeout)} stop sidekiq0"
      sudo "sv -w #{fetch(:runit_timeout)} stop sidekiq1"
      sudo "sv -w #{fetch(:runit_timeout)} stop sidekiq2"
    end
  end

  Rake::Task["sidekiq:start"].clear_actions
  task :start do
    on roles fetch(:sidekiq_roles) do
      sudo "sv start sidekiq0"
      sudo "sv start sidekiq1"
      sudo "sv start sidekiq2"
    end
  end
end

after 'deploy:publishing', 'deploy:restart'
