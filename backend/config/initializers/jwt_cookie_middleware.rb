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
      # Web SPA: mueve el token del header visible a cookie httpOnly
      headers.delete('Authorization')
      headers.delete('authorization')
      Rack::Utils.set_cookie_header!(headers, 'jwt_token', {
        value:     jwt,
        path:      '/',
        expires:   Time.now + 12 * 3600,
        httponly:  true,
        secure:    ENV.fetch('RAILS_ENV', 'development') == 'production',
        same_site: ENV.fetch('RAILS_ENV', 'development') == 'production' ? 'None' : 'Lax',
      })
    end
    # Mobile: Authorization header se mantiene intacto para que la app lo lea

    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before 0, JwtCookieMiddleware
