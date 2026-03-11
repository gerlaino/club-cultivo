Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # App de gestión interna (con autenticación)
  allow do
    origins "http://localhost:5173",           # Dev local
            "https://club-cultivo-1.onrender.com"  # Producción

    resource "*",
             headers: :any,
             expose: ['Authorization'],
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



