source 'https://rubygems.org'

ruby '2.3.1'

# FRAMEWORK
gem 'rails', '4.1.16'
gem 'configoro'
gem 'redis-rails'
gem 'redis-rack-cache'
gem 'rack-cache', require: 'rack/cache'
gem 'boolean'

# AUTHENTICATION
gem 'devise'

# MODELS
gem 'pg'
gem 'stringex', '2.2.0' # 2.5.2 forces config.enforce_available_locales to true for some stupid reason
gem 'slugalicious'
gem 'validates_timeliness'
gem 'find_or_create_on_scopes'
gem 'rails-observers'
gem 'after-commit-on-action'

# ElASTICSEARCH
gem 'elasticsearch-rails', '~> 0.1.9'
gem 'elasticsearch-model', '~> 0.1.9'
gem 'elasticsearch-dsl', '~> 0.1.3'

# VIEWS
gem 'jquery-rails'
gem 'font-awesome-rails'
gem 'twitter-typeahead-rails', '0.9.3' # 0.10.2 breaks locale key filtering
gem 'dropzonejs-rails'
gem 'kaminari'
gem 'slim-rails'
gem 'autoprefixer-rails'

# UTILITIES
gem 'json'
gem 'rugged', git: 'https://github.com/brandonweeks/rugged.git', tag: 'v0.24.0-square0', submodules: true
gem 'coffee-script'
gem 'unicode_scanner'
gem 'httparty'
gem 'similar_text', '~> 0.0.4'
gem 'paperclip', '>= 4.2.2'
gem 'aws-sdk'
gem 'execjs'
gem 'safemode'
gem 'sentry-raven'

# IMPORTING
gem 'nokogiri', '>= 1.6.7.2'
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
gem 'sidekiq', '4.2.10'
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
gem 'hogan_assets'

source 'https://rails-assets.org' do
  gem 'rails-assets-raven-js'
end

group :development do
  gem 'capistrano', '~> 3.10'
  gem 'capistrano-bundler', '~> 1.3'
  gem 'capistrano-rails', '~> 1.3'
  gem 'capistrano-rvm', '~> 0.1'
  gem 'capistrano-sidekiq', github: 'seuros/capistrano-sidekiq'
  gem 'redcarpet', require: nil
  gem 'web-console', '~> 2.0'
  gem 'yard', require: nil, platform: :mri
end

group :test do
  gem 'rspec-rails', '~> 3.0'
  gem 'factory_girl_rails'
  gem 'timecop'
  gem 'pry-nav'
  gem 'database_cleaner'
end

# Doesn't work in Rails 4
group :development, :test do
  gem 'mailcatcher', '~> 0.6.4'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'pry'
end
