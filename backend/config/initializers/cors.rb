Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Los orígenes de la app salen de `App.origenes_permitidos` (ver `config/application.rb`): es la
  # MISMA lista que usa el handshake de ActionCable, y estaba escrita dos veces. Se configuran por
  # ENV con FRONTEND_URL (dominio propio) y EXTRA_CORS_ORIGINS (lista separada por comas, para la
  # transición de dominio).
  # Los localhost sólo fuera de producción: con `credentials: true`, aceptarlos en producción
  # dejaba que cualquier cosa corriendo en el 5173 de la máquina de un usuario hablara con la API
  # con su sesión (barrido de seguridad, 13-oct-2026).
  locales = Rails.env.production? ? [] : ['http://localhost:5173', 'http://localhost:5174']
  app_origins = [*locales, *App.origenes_permitidos].uniq

  allow do
    origins(*app_origins)
    resource "*",
             headers: :any,
             expose:  ['Authorization'],
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             credentials: true
  end

  # NO hay un segundo bloque para `/public/*`. Había uno que permitía `https://tuclub.com` y
  # `https://www.tuclub.com` —dominios de ejemplo que no son nuestros— para la web pública por
  # club, que se retiró. Los endpoints públicos que quedan (el QR de una planta, el carnet, el
  # pasaporte de dispensa) los consume la propia SPA desde el mismo origen, así que ya entran por
  # el bloque de arriba.
end
