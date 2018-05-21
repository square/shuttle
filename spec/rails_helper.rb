# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'rails_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'sidekiq/testing'
require 'paperclip/matchers'
Dir[Rails.root.join('spec/spec_support/**/*.rb')].each { |f| require f }


# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Clear Redis before each test
  config.before :each do
    # Shuttle keys
    keys = Shuttle::Redis.keys('shuttle_*')
    Shuttle::Redis.del(*keys) unless keys.empty?

    # RedisMutex keys
    keys = Shuttle::Redis.keys('RedisMutex:*')
    Shuttle::Redis.del(*keys) unless keys.empty?
  end

  # Capybara
  if ENV['RAILS_ENV'] == 'acceptance'
    config.include Capybara::DSL
    Capybara.javascript_driver = :webkit
  else
    config.filter_run_excluding capybara: true
  end

  # Sidekiq
  config.before :suite do
    Sidekiq::Testing.inline!
  end

  # DatabaseCleaner
  config.before(:suite) do
    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean_with :truncation
  end
  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  # Paperclip
  config.include Paperclip::Shoulda::Matchers

  # Repository mocking
  config.before :each do
    allow(Rugged::Repository).to receive(:clone_at).and_call_original
    allow(Rugged::Repository).to receive(:clone_at).with(/^git:\/\/git\.example\.com\/square\/project-/, an_instance_of(String), an_instance_of(Hash)).
        and_return(instance_double('Rugged::Repository'))
  end

  # Devise
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include RequestSpecHelper, type: :request

  # Clear repo directories
  config.before :each do
    Pathname.glob(Project::REPOS_DIRECTORY.join('*.git')).each(&:rmtree)
    if Project::WORKING_REPOS_DIRECTORY.exist?
      Project::WORKING_REPOS_DIRECTORY.children.reject { |e| e.basename.to_s.start_with?('.') }.each(&:rmtree)
    end
  end

  # ElasticSearch
  config.before(:suite) { reset_elastic_search }
end

def reset_elastic_search
  ActiveRecord::Base.subclasses.each do |model|
    next unless model.respond_to?(:__elasticsearch__)
    model.__elasticsearch__.create_index! force: true
    model.import(force: true)
    model.__elasticsearch__.client.indices.flush(index: model.__elasticsearch__.index_name, force: true)
  end
end

def regenerate_elastic_search_indexes
  ActiveRecord::Base.subclasses.each do |model|
    next unless model.respond_to?(:__elasticsearch__)
    model.import(refresh: true)
    model.__elasticsearch__.client.indices.flush(index: model.__elasticsearch__.index_name, force: true)
  end
end
