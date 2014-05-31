source 'https://rubygems.org'
source 'https://0858cb81:19556f67@www.mikeperham.com/rubygems/'

# FRAMEWORK
gem 'rails', '4.0.3'
gem 'configoro'
gem 'redis-rails'
gem 'rack-cache', require: 'rack/cache'
gem 'boolean'

# AUTHENTICATION
gem 'devise'

# MODELS
gem 'pg'
gem 'slugalicious'
gem 'validates_timeliness'
gem 'has_metadata_column'
gem 'find_or_create_on_scopes'
gem 'composite_primary_keys', github: 'RISCfuture/composite_primary_keys', branch: 'rebase'
gem 'rails-observers'
gem 'tire'

# VIEWS
gem 'jquery-rails'
gem 'font-awesome-rails'
gem 'twitter-typeahead-rails'
gem 'dropzonejs-rails'
gem 'kaminari'
gem 'slim-rails'

# UTILITIES
gem 'json'
gem 'git', github: 'RISCfuture/ruby-git', ref: '14d05318c3c22352564dfb3acf45ee1a29a09864' # Fixes mirror issue
gem 'coffee-script'
gem 'unicode_scanner'
gem 'httparty'
gem 'similar_text', '~> 0.0.4'
gem 'paperclip'
gem 'aws-sdk'

# IMPORTING
gem 'therubyracer', platform: :mri, require: 'v8'
gem 'nokogiri'
gem 'CFPropertyList', require: 'cfpropertylist'
gem 'parslet'
gem 'mustache'
gem 'html_validation'

# EXPORTING
gem 'libarchive'

# WORD SUBSTITUTION
gem 'uea-stemmer'

# PSEUDO TRANSLATION
gem 'faker'

# BACKGROUND JOBS
gem 'sidekiq', '<3.0.0'
gem 'sidekiq-pro'
gem 'sidekiq-failures', github: 'mhfs/sidekiq-failures'
gem 'sinatra', require: nil
gem 'whenever', require: nil

# REDIS
gem 'redis-mutex'
gem 'redis-namespace'

# ASSETS
gem 'sprockets-rails'
gem 'sass-rails', '4.0.3' # bugfix for sass 3.3 (in)compatibility
gem 'coffee-rails'
gem 'uglifier'
gem 'less-rails'
gem 'hogan_assets'

group :development do
  gem 'redcarpet', require: nil
  gem 'yard', require: nil, platform: :mri
end

group :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'timecop'
  gem 'pry'
  gem 'pry-nav'
  gem 'test_after_commit'
end

# Include these gems if you're running acceptance tests.
group :acceptance do
  # gem 'capybara'
  # gem 'capybara-webkit'
end

gem 'sql_origin', groups: [:development, :test]

# Doesn't work in Rails 4
group :development, :test do
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'mailcatcher'
  #gem 'jasminerice'
  #gem 'guard-jasmine'
end

# SQUARE
gem 'squash_ruby', '>= 1.4.0', require: 'squash/ruby'
gem 'squash_rails', require: 'squash/rails', github: 'SquareSquash/rails', ref: 'e3c4207d2b90d27fa9ff4ba72c50ba354f507163' # deploy issue
gem 'newrelic_rpm', '>= 3.7.3'
group :development do
  gem 'capistrano'
  gem 'capistrano-rvm', '>= 0.1.0' # seems to really like 0.0.3
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
end
