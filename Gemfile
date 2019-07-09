git_source(:github) { |repo| "https://github.com/#{repo}.git" }

if system('curl -s https://gems.vip.global.square > /dev/null') != false
  source 'https://gems.vip.global.square'
else
  source 'https://rubygems.org'
end

ruby '2.4.6'

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
gem 'devise_security_extension'

# MODELS
gem 'pg', '< 1.0'
gem 'stringex'
gem 'slugalicious'
gem 'validates_timeliness'
gem 'find_or_create_on_scopes'
gem 'rails-observers'
gem 'after-commit-on-action'

# REPORTING
gem 'postgres_ext'
gem 'active_record_union'

# ELASTICSEARCH
gem 'chewy'

# VIEWS
gem 'jquery-rails'
gem 'bootstrap'
gem 'font-awesome-rails'
gem 'twitter-typeahead-rails'
gem 'dropzonejs-rails'
gem 'kaminari'
gem 'slim-rails'
gem 'autoprefixer-rails'

# UTILITIES
gem 'bundler'
gem 'json'
gem 'rugged', github: 'squarit/rugged', tag: 'v0.27.2-square0', submodules: true
gem 'coffee-script'
gem 'unicode_scanner'
gem 'httparty'
gem 'similar_text'
gem 'rack-attack'
# temporary fix uninitialized constant Paperclip::Storage::S3::AWS bug. Should consider using latest version after upgrading rails to 4.2 or higher version
gem 'paperclip', github: 'thoughtbot/paperclip', ref: '523bd46c768226893f23889079a7aa9c73b57d68'
gem 'aws-sdk', '< 3'
gem 'execjs'
gem 'safemode'
gem 'pivot_table'
gem 'sentry-raven'

# IMPORTING
gem 'nokogiri'
gem 'CFPropertyList', require: 'cfpropertylist'
gem 'parslet'
gem 'mustache'
gem 'html_validation'
gem 'diff-lcs'
gem 'rubyXL', github: 'weshatheleopard/rubyXL'
gem 'docx', '0.3.1', github: 'visoft/docx'

# EXPORTING
gem 'libarchive'

# WORD SUBSTITUTION
gem 'uea-stemmer'

# PSEUDO TRANSLATION
gem 'faker'

# BACKGROUND JOBS
source 'https://gems.vip.global.square/private' do
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
gem 'awesome_print'

source 'https://rails-assets.org' do
  gem 'rails-assets-raven-js'
end

# METRICS
gem 'newrelic_rpm'

group :development do
  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano-sidekiq'
  gem 'redcarpet', require: nil
  gem 'yard', require: nil, platform: :mri
  gem 'better_errors'
  gem 'guard-rspec', require: false
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'binding_of_caller'
end

group :dummy do
  # needed for deployment
  gem 'rbnacl', '< 5.0'
  gem 'rbnacl-libsodium'
  gem 'bcrypt_pbkdf', '< 2.0'
end

group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'timecop'
  gem 'pry-byebug'
  gem 'database_cleaner'
  gem 'capybara'
end

gem "message_format", "~> 0.0.5"
