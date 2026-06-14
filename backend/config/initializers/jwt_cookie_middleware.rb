# Intercepta el Authorization header que Devise JWT añade en la capa Rack
# (después del controller, por eso no se puede hacer desde el controller).
# - Web SPA: mueve el JWT a una cookie httpOnly (inaccesible desde JS)
# - Mobile (X-Mobile-Client: true): deja el Authorization header intacto
class JwtCookieMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    auth_value = headers['Authorization'] || headers['authorization']
    jwt        = auth_value&.sub(/\ABearer /i, '')
    return [status, headers, body] unless jwt.present?

    request = Rack::Request.new(env)

    unless request.get_header('HTTP_X_MOBILE_CLIENT') == 'true'
      # Web SPA: el JWT viaja SOLO en cookie httpOnly (inaccesible desde JS).
      # Exponerlo además en el header lo dejaba al alcance de cualquier XSS.
      # El SPA se sirve same-origin (spa_fallback), así que la cookie siempre llega.
      Rack::Utils.set_cookie_header!(headers, 'jwt_token', {
        value:     jwt,
        path:      '/',
        expires:   Time.now + 12 * 3600,
        httponly:  true,
        secure:    ENV.fetch('RAILS_ENV', 'development') == 'production',
        # Lax: la SPA se sirve del mismo origen que la API (Rails sirve el index.html),
        # así que la cookie es first-party. 'None' era innecesario y lo bloquea el
        # modo incógnito (que filtra cookies third-party). Lax funciona en incógnito.
        same_site: 'Lax',
      })
      headers.delete('Authorization')
      headers.delete('authorization')
    end
    # Mobile (X-Mobile-Client): el Authorization header se mantiene intacto

    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before 0, JwtCookieMiddleware
