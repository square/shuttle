source 'https://rubygems.org'

# FRAMEWORK
gem 'rails', '>= 4.0'
gem 'configoro'

# AUTHENTICATION
gem 'devise', github: 'plataformatec/devise'

# MODELS
gem 'pg', '< 0.14'
gem 'slugalicious'
gem 'validates_timeliness'
gem 'has_metadata_column'
gem 'find_or_create_on_scopes'
gem 'composite_primary_keys', github: 'RISCfuture/composite_primary_keys'
gem 'rails-observers'

# VIEWS
gem 'jquery-rails'
gem 'erector', github: 'RISCfuture/erector'
gem 'font-awesome-rails'

# UTILITIES
gem 'json'
gem 'git', github: 'RISCfuture/ruby-git'
gem 'coffee-script'
gem 'unicode_scanner'
gem 'httparty'

# IMPORTING
gem 'therubyracer', platform: :mri, require: 'v8'
gem 'nokogiri'
gem 'CFPropertyList', require: 'cfpropertylist'

# EXPORTING
gem 'libarchive'

# WORD SUBSTITUTION
gem 'uea-stemmer'

# BACKGROUND JOBS
gem 'sidekiq'
# Versions below 1.3.0 cause Sidekiq dashboard to break
gem 'slim', '>= 1.3.8'
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
gem 'twitter-bootstrap-rails'

group :development do
  gem 'redcarpet', require: nil
  gem 'yard', require: nil, platform: :mri
end

group :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
end

# Doesn't work in Rails 4
group :development, :test do
  #gem 'jasminerice'
  #gem 'guard-jasmine'
end
