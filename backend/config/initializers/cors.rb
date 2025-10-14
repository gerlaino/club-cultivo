# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Construimos la lista de orígenes permitidos
  origins_list = ['http://localhost:5173']

  env_origins = ENV['CORS_ORIGINS']
  if env_origins && !env_origins.strip.empty?
    # Permití uno o varios orígenes separados por coma
    # Ej: "https://tu-front.onrender.com,https://otro-dominio.com"
    origins_list.concat(env_origins.split(',').map(&:strip))
  end

  allow do
    origins origins_list
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true
  end
end


