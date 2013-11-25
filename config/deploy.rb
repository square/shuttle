set :application, 'shuttle'
set :repo_url, 'https://git.squareup.com/intl/shuttle.git'

set :deploy_to, "/app/#{fetch :application}"

set :linked_files, %w{config/database.yml}
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle tmp/repos}

set :current_revision, `git rev-parse #{fetch :branch}`.chomp

set :rvm_type, :system
set :rvm_ruby_version, "2.0.0-p353@#{fetch :application}"

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :finishing, 'deploy:cleanup'

  before :publishing, :write_revision do
    on roles(:app) do
      execute %{echo "#{fetch :current_revision}" > #{release_path.join('REVISION')}}
    end
  end

  after :finishing, :notify_squash do
    on roles(:web), limit: 1 do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute 'bin/rails', "runner 'Squash::Ruby.notify_deploy #{fetch(:rails_env).inspect}, #{fetch(:current_revision).inspect}, #{Socket.gethostname.inspect}'"
        end
      end
    end
  end
end
