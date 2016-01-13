# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Shuttle
  class Application < Rails::Application
    # Load configoro settings here so that the settings can be used in application.rb, development.rb, production.rb, etc...
    config.before_configuration do
      Configoro.initialize
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths << config.root.join('lib')
    config.autoload_paths << config.root.join('app', 'models', 'concerns') #RAILS4 remove
    config.autoload_paths << config.root.join('app', 'controllers', 'concerns') #RAILS4 remove
    config.autoload_paths << config.root.join('app', 'models', 'observers')
    config.autoload_paths << config.root.join('app', 'presenters')
    config.autoload_paths << config.root.join('app', 'mediators')
    config.autoload_paths << config.root.join('app', 'services')
    config.autoload_paths << config.root.join('app', 'support')

    # Activate observers that should always be running.
    config.active_record.observers     = :comment_observer, :commit_observer, :article_observer, :issue_observer, :translation_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone                   = 'Pacific Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    config.active_record.schema_format = :sql

    config.log_tags       = [:uuid]

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'
    config.generators do |g|
      g.template_engine :slim
      g.test_framework :rspec, fixture: true, views: false
      g.integration_tool :rspec
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end

    # Precompile additional assets.
    # application.js.coffee, application.css, and all non-JS/CSS in app/assets folder are already added.
    config.assets.precompile += %w(
      *.png *.gif *.jpg
      incontext.js
      incontext.css
    )
  end
end

# no idea why this is necessary
require 'errors'
require Rails.root.join('lib', 'importer', 'base')
Dir.glob(Rails.root.join('lib', 'importer', '*.rb')).each { |f| require f }
require Rails.root.join('lib', 'exporter', 'base')
Dir.glob(Rails.root.join('lib', 'exporter', '*.rb')).each { |f| require f }
require Rails.root.join('lib', 'fencer')
require Rails.root.join('lib', 'compiler')
Dir.glob(Rails.root.join('lib', 'fencer', '*.rb')).each { |f| require f }
require Rails.root.join('lib', 'localizer', 'base')
Dir.glob(Rails.root.join('lib', 'localizer', '*.rb')).each { |f| require f }
