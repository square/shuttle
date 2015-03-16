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
set :repo_url, YAML.load(ERB.new(IO.read(File.join(File.dirname(__FILE__), 'environments', 'common', 'app.yml'))).result)["repo_url"]

set :branch, 'deployable'

set :deploy_to, "/app/#{fetch :application}"

set :linked_files, %w{  config/database.yml
                        config/environments/staging/app.yml
                        config/environments/staging/paperclip.yml
                        config/environments/staging/squash.yml
                        config/environments/production/app.yml
                        config/environments/production/paperclip.yml
                        config/environments/production/squash.yml
                        config/environments/production/stash.yml }
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle tmp/repos tmp/working_repos}

set :rvm_type, :system
set :rvm_ruby_version, "2.0.0-p576@#{fetch :application}"

set :whenever_roles, [:app, :primary_cron]
set :sidekiq_role, [] # make the default cap sidekiq:* commands no-ops, instead, rely on 'sv' commands as below

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  namespace :sidekiq do
    task :restart do
      on roles(:sidekiq) do
        sudo "sv term sidekiq"
      end
    end
  end

  after :finishing, 'deploy:cleanup'
  after :finishing, 'deploy:restart'
  after :finishing, 'deploy:sidekiq:restart'
end

before 'deploy:publishing', 'squash:write_revision'
