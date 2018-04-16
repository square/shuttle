source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.3.1'

# FRAMEWORK
gem 'rails', '4.2.10'
gem 'configoro'
gem 'redis-rails'
gem 'rack-cache', require: 'rack/cache'
gem 'redis-rack-cache'
gem 'boolean'
gem 'faraday'
gem 'rubyzip'

# AUTHENTICATION
gem 'devise'

# MODELS
gem 'pg', '< 1.0'
gem 'stringex'
gem 'slugalicious'
gem 'validates_timeliness'
gem 'find_or_create_on_scopes'
gem 'rails-observers'
gem 'after-commit-on-action'

# ElASTICSEARCH
gem 'elasticsearch', '< 6.0'
gem 'elasticsearch-rails'
gem 'elasticsearch-model'
gem 'elasticsearch-dsl'

# VIEWS
gem 'jquery-rails'
gem 'font-awesome-rails'
gem 'twitter-typeahead-rails'
gem 'dropzonejs-rails'
gem 'kaminari'
gem 'slim-rails'
gem 'autoprefixer-rails'

# UTILITIES
gem 'json'
gem 'rugged', github: 'brandonweeks/rugged', tag: 'v0.24.0-square0', submodules: true
gem 'coffee-script'
gem 'unicode_scanner'
gem 'httparty'
gem 'similar_text'
# temporary fix uninitialized constant Paperclip::Storage::S3::AWS bug. Should consider using latest version after upgrading rails to 4.2 or higher version
gem 'paperclip', github: 'thoughtbot/paperclip', ref: '523bd46c768226893f23889079a7aa9c73b57d68'
gem 'aws-sdk', '< 3'
gem 'execjs'
gem 'safemode'
gem 'pivot_table'

# IMPORTING
gem 'nokogiri'
gem 'CFPropertyList', require: 'cfpropertylist'
gem 'parslet'
gem 'mustache'
gem 'html_validation'
gem 'diff-lcs'

# EXPORTING
gem 'libarchive'

# WORD SUBSTITUTION
gem 'uea-stemmer'

# PSEUDO TRANSLATION
gem 'faker'

# BACKGROUND JOBS
source "https://gems.contribsys.com/" do
  gem 'sidekiq-pro', '= 3.4.5'
end
gem 'sidekiq-failures', github: 'mhfs/sidekiq-failures'
gem 'sinatra', require: nil
gem 'whenever', require: nil

# REDIS
gem 'redis-mutex'
gem 'redis-namespace'

# ASSETS
gem 'sprockets-rails'
gem 'sass-rails'
gem 'coffee-rails'
gem 'uglifier'
gem 'hogan_assets', github: 'rubenrails/hogan_assets', branch: 'fix_for_sprockets' # sprockets 3 compatibility

group :development do
  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano-sidekiq'
  gem 'redcarpet', require: nil
  gem 'yard', require: nil, platform: :mri
  gem 'better_errors'
end

group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'timecop'
  gem 'pry-byebug'
  gem 'database_cleaner'
  gem 'capybara'
end
