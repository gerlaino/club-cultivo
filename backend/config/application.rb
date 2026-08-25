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
  # ── Desde dónde se acepta una conexión ────────────────────────────────────────
  #
  # Es la misma lista para dos cosas: CORS (`config/initializers/cors.rb`) y el handshake de
  # ActionCable (`config/environments/production.rb`). Vive ACÁ y en un solo lugar porque estaba
  # escrita dos veces y las dos copias dejaron de coincidir.
  #
  # Y las dos anotaban `club-cultivo-1.onrender.com` —el sitio VIEJO— sin anotar el servidor donde
  # la app corre de verdad. Eso importa el día que se mueve el dominio: al pasar `FRONTEND_URL` a
  # `cultivoespacial.com`, el host de Render salía de la lista, y a todo el que siguiera entrando
  # por ahí —durante las horas que tarda el DNS en propagarse— se le cortaba el tiempo real SIN UN
  # ERROR A LA VISTA. La pantalla se queda quieta y parece que no pasa nada.
  #
  # Por eso los hosts propios se SUMAN, no se reemplazan: durante la transición conviven los dos.
  HOSTS_PROPIOS = [
    'https://cultivo-staging-api.onrender.com', # producción — el nombre engaña, no es staging
    'https://club-cultivo-1.onrender.com',      # el static legacy, mientras siga en pie
  ].freeze

  def self.origenes_permitidos
    [
      *HOSTS_PROPIOS,
      ENV['FRONTEND_URL'],
      *ENV['EXTRA_CORS_ORIGINS'].to_s.split(','),
    ].compact.map(&:strip).reject(&:empty?).uniq
  end

  # La dirección de la app para armar links FUERA de un request (mails, jobs, PDFs).
  #
  # `FRONTEND_URL` manda; si no está, se arma con `APP_HOST`, que es el que ya usa
  # `config/initializers/default_url_options.rb`. Antes el mailer del portal tenía escrito a mano
  # `https://app.cultivoespacial.com` como respaldo: un SUBDOMINIO, cuando la dirección elegida es
  # la raíz. Es el mail donde el paciente recibe su contraseña, así que ese link tiene que llevar
  # a algún lado.
  def self.base_url
    frontend = ENV['FRONTEND_URL'].to_s.strip
    return frontend unless frontend.empty?

    host = ENV['APP_HOST'].to_s.strip
    host.empty? ? 'http://localhost:3001' : "https://#{host}"
  end

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
    #
    # Va como INITIALIZER y no suelto en el cuerpo de la clase, y la diferencia importa: un
    # initializer se REGISTRA al definir la clase pero se EJECUTA recién en
    # `Rails.application.initialize!`, o sea sólo cuando la app arranca de verdad.
    #
    # Suelto en el cuerpo se disparaba con el simple `require_relative "config/application"` del
    # Rakefile, es decir en CUALQUIER tarea de rake. Eso rompía `rake backup:create`, que está
    # escrita a propósito SIN depender de `:environment` porque sólo necesita `pg_dump` y las
    # credenciales de S3. Resultado: **el backup diario de producción falló durante 13 días**
    # pidiendo unas claves que no usa para nada.
    #
    # Y que no las tenga es lo correcto: el backup produce un dump con los datos cifrados adentro.
    # Darle además las claves para descifrarlos sería guardar la caja fuerte y la llave en el
    # mismo lugar.
    initializer 'cultivo.verificar_claves_de_cifrado', before: :load_config_initializers do
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
