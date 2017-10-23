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

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'database_cleaner'

require 'paperclip/matchers'
require 'sidekiq/testing/inline'

# Requires shared examples in model concerns
Dir[Rails.root.join('spec', 'models', 'concerns', 'common_locale_logic_spec.rb')].each { |f| require f }

# Clear out the database to avoid duplicate key conflicts
Dir[Rails.root.join('app', 'models', '**', '*.rb')].each { |f| require f }
ActiveRecord::Base.subclasses.each do |model|
  model.connection.execute "TRUNCATE #{model.table_name} CASCADE"
end

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures                 = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  config.before :each do
    allow(Rugged::Repository).to receive(:clone_at).and_call_original
    allow(Rugged::Repository).to receive(:clone_at).with(/^git:\/\/git\.example\.com\/square\/project-/, an_instance_of(String), an_instance_of(Hash)).
      and_return(instance_double('Rugged::Repository'))
  end

  config.include Devise::TestHelpers, type: :controller
  config.include Paperclip::Shoulda::Matchers

  if ENV['RAILS_ENV'] == 'acceptance'
    config.include Capybara::DSL
    Capybara.javascript_driver = :webkit
  else
    config.filter_run_excluding :capybara => true
  end

  config.before :each do
    # Clear out Redis
    RedisMutex.sweep
    Shuttle::Redis.flushdb
  end

  config.before :suite do
    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean_with(:truncation)
  end

  config.after :each do
    DatabaseCleaner.clean
  end

  # rspec-rails 3 will no longer automatically infer an example group's spec type
  # from the file location. You can explicitly opt-in to the feature using this
  # config option.
  # To explicitly tag specs without using automatic inference, set the `:type`
  # metadata manually:
  #
  #     describe ThingsController, :type => :controller do
  #       # Equivalent to being in spec/controllers
  #     end
  config.infer_spec_type_from_file_location!
end

FactoryGirl::SyntaxRunner.class_eval do
  include RSpec::Mocks::ExampleMethods
end

def reset_elastic_search
  ActiveRecord::Base.subclasses.each do |model|
    next unless model.respond_to?(:__elasticsearch__)
    model.__elasticsearch__.create_index! force: true
    model.import(force: true)
  end
end

def regenerate_elastic_search_indexes
  ActiveRecord::Base.subclasses.each do |model|
    next unless model.respond_to?(:__elasticsearch__)
    model.import(force: true)
  end
end
