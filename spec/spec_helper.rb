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
require 'rspec/autorun'

require 'sidekiq/testing/inline'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

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
  config.use_transactional_fixtures                 = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  config.include Devise::TestHelpers, type: :controller

  config.before :each do
    # Clear out Redis
    Redis::Mutex.sweep
    Shuttle::Redis.flushdb
  end
end

def reset_elastic_search
  ActiveRecord::Base.subclasses.each do |model|
    next unless model.respond_to?(:tire)
    index = model.tire.index
    Tire::Tasks::Import.delete_index(index)
    Tire::Tasks::Import.create_index(index, model)
  end
end

def regenerate_elastic_search_indexes
  ActiveRecord::Base.subclasses.each do |model|
    next unless model.respond_to?(:tire)
    Tire::Tasks::Import.import_model(model.tire.index, model, {})
  end
end

