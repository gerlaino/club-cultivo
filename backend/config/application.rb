require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: "_club_session"
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.default_locale = :es
    config.i18n.available_locales = [:es, :en]

    config.time_zone = 'Buenos Aires'

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # ==> Active Record Encryption (datos sensibles de salud + DNI cifrados at-rest)
    # Ley 25.326 art. 9 / Res. AAIP 47/2018 (nivel reforzado para datos sensibles).
    # Las claves viajan por ENV: credentials.yml.enc está gitignored (per-entorno),
    # así que no sirve para propagar claves a prod. Mismo patrón que DEVISE_JWT_SECRET_KEY.
    # Sin claves la app NO arranca — no hay fallback silencioso.
    %w[
      ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
      ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
      ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
    ].each do |var|
      next if ENV[var].present?
      raise "Falta #{var}: la app no arranca sin las claves de cifrado at-rest " \
            "(datos sensibles de salud). No hay fallback. Definila en backend/.env (dev) " \
            "o en las env vars del deploy (prod)."
    end

    config.active_record.encryption.primary_key         = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key   = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

    # Transición: leer filas viejas en texto plano y, para columnas determinísticas,
    # buscar tanto por valor cifrado como sin cifrar hasta completar el backfill.
    # Endurecer (support_unencrypted_data = false) una vez backfilleada la prod.
    config.active_record.encryption.support_unencrypted_data = true
    config.active_record.encryption.extend_queries           = true
  end
end
