Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Orígenes permitidos para la app interna (con cookies). Los fijos + los que vengan
  # por ENV: FRONTEND_URL (dominio principal) y EXTRA_CORS_ORIGINS (lista separada por
  # comas). Así, al poner el dominio nuevo, NO hace falta tocar este archivo.
  app_origins = [
    "http://localhost:5173",                  # Dev local
    "http://localhost:5174",                  # Dev local (puerto alternativo)
    "https://club-cultivo-1.onrender.com",    # Producción (host de render)
    ENV["FRONTEND_URL"],                       # Dominio propio (ej. https://cultivoespacial.com)
    *ENV["EXTRA_CORS_ORIGINS"].to_s.split(",").map(&:strip),
  ].compact.reject(&:blank?).uniq

  # App de gestión interna (con autenticación)
  allow do
    origins(*app_origins)

    resource "*",
             headers: :any,
             expose:  ['Authorization'],
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             credentials: true
  end

  # Web pública (sin autenticación)
  allow do
    origins "http://localhost:5174",           # Dev local (cuando la hagas)
            ENV['PUBLIC_WEB_URL'] || "https://tuclub.com",  # Tu dominio público
            ENV['PUBLIC_WEB_URL_WWW'] || "https://www.tuclub.com"

    resource "/public/*",
             headers: :any,
             methods: [:get, :options, :head],
             credentials: false  # No necesita cookies para endpoints públicos
  end
end



