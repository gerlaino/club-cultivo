Rails.application.routes.default_url_options[:host] = "localhost:3001"
Rails.application.config.action_mailer.default_url_options = { host: "localhost", port: 3001 }
