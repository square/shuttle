# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

# Includes tasks from other gems included in your Gemfile
require 'capistrano/rvm'
require 'capistrano/bundler'
require 'capistrano/rails'
require 'sidekiq/capistrano'
require 'whenever/capistrano'
require 'squash/rails/capistrano3'
require 'squash/javascript/capistrano'

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.cap').each { |r| import r }
