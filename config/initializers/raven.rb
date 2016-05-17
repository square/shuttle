require 'raven'

Raven.configure do |config|
  config.tags = { environment: Rails.env }
end
