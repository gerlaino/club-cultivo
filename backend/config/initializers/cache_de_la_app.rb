# Cuánto puede guardar el navegador lo que Rails sirve de `public/` (el build del frontend).
#
# `ActionDispatch::Static` los mandaba SIN `Cache-Control`, y sin esa indicación el navegador
# adivina: guarda el archivo un 10 % de lo que lleva sin cambiar. Con un deploy de hace tres días,
# `/` (que es `public/index.html`, no `spa_fallback`) quedaba guardado horas y se veía la versión
# anterior de la app aunque producción ya tuviera la nueva (26-oct-2026).
#
# - La cáscara (`index.html`, `sw.js`, el manifest): `no-cache` = se puede guardar pero se pregunta
#   SIEMPRE si cambió. Si no cambió vuelve un 304 vacío, que no cuesta nada.
# - `/assets/*`: llevan el hash del contenido en el nombre, si cambian cambia la URL. Se guardan un
#   año sin preguntar.
#
# Sólo se pone si la respuesta no trae ya uno: `spa_fallback` manda `no-store` y lo respeta.
class CacheDeLaApp
  CASCARA = %w[/ /index.html /sw.js /manifest.webmanifest].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    # Rack 3 pide los nombres en minúscula; se mira también la otra forma por si un middleware viejo.
    return [status, headers, body] if headers['Cache-Control'].present? || headers['cache-control'].present?

    path = env['PATH_INFO']
    if CASCARA.include?(path)
      headers['cache-control'] = 'no-cache'
    elsif path.start_with?('/assets/') && status == 200
      headers['cache-control'] = 'public, max-age=31536000, immutable'
    end
    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::Static, CacheDeLaApp
