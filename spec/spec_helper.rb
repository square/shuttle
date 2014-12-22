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

  config.deprecation_stream = 'log/rspec-deprecations.log'

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures                 = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

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
    Redis::Mutex.sweep
    Shuttle::Redis.flushdb
  end

  config.before :suite do
    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean_with(:truncation)
  end

  config.after :each do |example|
    DatabaseCleaner.clean
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

# Sidekiq Batches do not run their on-success callbacks in the test environment
# because this feature is implemented using Sidekiq middleware. This shim
# restores the on-success callback behavior in test.after() do

class Sidekiq::Batch
  def jobs_with_callbacks(*args, &block)
    # only the outermost call to Batch#jobs should have hacked behavior when
    # it completes
    if Thread.current[:in_jobs_with_callback]
      return jobs_without_callbacks(*args, &block)
    end
    Thread.current[:in_jobs_with_callback] = true

    # assume jobs are run inline and will finish before this method completes
    jobs_without_callbacks(*args, &block)

    Thread.current[:in_jobs_with_callback] = false

    # now that all jobs are finished, execute the on_success callback
    status = Status.new(bid)
    Array.wrap(callbacks['success']).each do |hash|
      hash.each_pair do |target, options|
        Sidekiq::Notifications::Callback.new('success', target.to_s).notify(status, options.stringify_keys)
      end
    end
    Array.wrap(callbacks['finished']).each do |hash|
      hash.each_pair do |target, options|
        Sidekiq::Notifications::Callback.new('finished', target.to_s).notify(status, options.stringify_keys)
      end
    end
  end
  alias_method_chain :jobs, :callbacks
end
