source 'https://rubygems.org'

ruby '2.3.1'

# FRAMEWORK
gem 'rails', '4.2.10'
gem 'configoro'
gem 'redis-rails'
gem 'redis-rack-cache'
gem 'rack-cache', require: 'rack/cache'
gem 'boolean'
gem 'faraday'
gem 'rubyzip'

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
gem 'elasticsearch', '< 6.0'
gem 'elasticsearch-rails'
gem 'elasticsearch-model'
gem 'elasticsearch-dsl'

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
# temporary fix uninitialized constant Paperclip::Storage::S3::AWS bug. Should consider using latest version after upgrading rails to 4.2 or higher version
gem 'paperclip', git: 'https://github.com/thoughtbot/paperclip', ref: '523bd46c768226893f23889079a7aa9c73b57d68'
gem 'aws-sdk'
gem 'execjs'
gem 'safemode'

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
gem 'hogan_assets', github: 'rubenrails/hogan_assets', branch: 'fix_for_sprockets' # sprockets 3 compatibility

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
  gem 'factory_bot_rails'
  gem 'timecop'
  gem 'pry-nav'
  gem 'database_cleaner'
  gem 'capybara'
end

# Doesn't work in Rails 4
group :development, :test do
  gem 'mailcatcher', '~> 0.6.4'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'pry'
end
