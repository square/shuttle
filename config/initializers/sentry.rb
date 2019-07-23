require 'raven'

if !Rails.env.test?
  Raven.configure do |config|
    config.dsn  = Shuttle::Configuration.sentry.dsn if Shuttle::Configuration.sentry.dsn
    config.secret_key  = Shuttle::Configuration.sentry.secret_key if Shuttle::Configuration.sentry.secret_key
    config.tags = { environment: Rails.env }
    config.excluded_exceptions = ['ActionController::RoutingError', 'Sidekiq::Shutdown']
  end
end
