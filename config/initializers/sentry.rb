require 'raven'

Raven.configure do |config|
  config.dsn  = Shuttle::Configuration.sentry.dsn if Shuttle::Configuration.sentry.dsn
  config.tags = { environment: Rails.env }
  config.excluded_exceptions = ['ActionController::RoutingError', 'Sidekiq::Shutdown']
end
