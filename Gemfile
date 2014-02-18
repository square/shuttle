source 'https://rubygems.org'

# FRAMEWORK
gem 'rails', '4.0.3'
gem 'configoro'

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
gem 'kaminari'
gem 'slim-rails'

# UTILITIES
gem 'json'
gem 'git', github: 'RISCfuture/ruby-git', ref: '14d05318c3c22352564dfb3acf45ee1a29a09864' # Fixes mirror issue
gem 'coffee-script'
gem 'unicode_scanner'
gem 'httparty'

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
gem 'sidekiq'
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
gem 'less-rails'
gem 'hogan_assets'

group :development do
  gem 'redcarpet', require: nil
  gem 'yard', require: nil, platform: :mri
end

group :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'pry'
  gem 'pry-nav'
end

gem 'sql_origin', groups: [:development, :test]

# Doesn't work in Rails 4
group :development, :test do
  #gem 'jasminerice'
  #gem 'guard-jasmine'
end
