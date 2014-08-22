source 'https://rubygems.org'
source 'https://0858cb81:19556f67@www.mikeperham.com/rubygems/'

# FRAMEWORK
gem 'rails', '4.0.9'
gem 'configoro'
gem 'redis-rails'
gem 'rack-cache', require: 'rack/cache'
gem 'boolean'

# AUTHENTICATION
gem 'devise'

# MODELS
gem 'pg'
gem 'stringex', '2.2.0' # 2.5.2 forces config.enforce_available_locales to true for some stupid reason
gem 'slugalicious'
gem 'validates_timeliness'
gem 'has_metadata_column', github: 'RISCfuture/has_metadata_column', branch: 'rails4', ref: 'dae0cda4835ff0903ac9b6b2a5ae5e64af15e119'
gem 'find_or_create_on_scopes'
gem 'composite_primary_keys', github: 'composite-primary-keys/composite_primary_keys', branch: 'ar_4.0.x'
gem 'rails-observers'
gem 'tire'
gem 'after-commit-on-action'

# VIEWS
gem 'jquery-rails'
gem 'font-awesome-rails'
gem 'twitter-typeahead-rails', '0.9.3' # 0.10.2 breaks locale key filtering
gem 'dropzonejs-rails'
gem 'kaminari'
gem 'slim-rails'

# UTILITIES
gem 'json'
gem 'git', github: 'RISCfuture/ruby-git', ref: '88076a50eb70fd96f2417b646fe37fb2f6c4cca4' # Fixes mirror issue
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
  gem 'rspec-rails', '< 3.0.0'
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
