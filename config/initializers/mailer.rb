
Rails.application.config.action_mailer.default_url_options = Shuttle::Configuration.mailer.default_url_options.symbolize_keys
Rails.application.config.action_mailer.default from: Shuttle::Configuration.mailer.from
