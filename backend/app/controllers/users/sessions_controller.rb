class Users::SessionsController < Devise::SessionsController
  respond_to :json

  # Sin esto, cerrar sesión como super admin devolvería 409 en vez de desloguear.
  skip_before_action :block_super_admin_sin_contexto!, raise: false

  # El filtro de Devise que contesta «ya estabas afuera» sin llegar a `destroy`. Mira la sesión de
  # Rails (`_club_session`, que muere al cerrar el navegador), no la cookie del token (7 días): con
  # el navegador reabierto creía que no había nadie, respondía 204 y NO borraba la cookie ni
  # revocaba el token. «Cerrar sesión» te mandaba al login y volver a `/` te metía de nuevo
  # (26-oct-2026). Cerrar sesión corre siempre; sin sesión, borrar una cookie que no está no daña.
  skip_before_action :verify_signed_out_user

  def create
    # ENTRAR ES CON LO QUE SE ESCRIBIÓ. Warden, antes de mirar usuario y clave, devuelve el que ya
    # esté en la sesión de Rails (`_club_session`): con esa cookie del usuario anterior viva —una
    # respuesta tardía la repone, o quedó del navegador— entrar como otra persona dejaba adentro al
    # anterior, con el token del anterior (27-oct-2026: lo destapó `rendicion.spec` al cambiar de
    # dispensadora a repartidor). Se suelta la sesión vieja y se autentica de cero.
    warden.logout(resource_name) if warden.authenticated?(resource_name)
    self.resource = warden.authenticate!(auth_options)

    # Las credenciales son válidas, pero el club apagó el módulo del que vive este rol. Se
    # rechaza acá para que el mensaje llegue en la pantalla de login y no como un 403 opaco
    # en cada pantalla de adentro. El guard de ApplicationController es el que manda de
    # verdad (cubre las sesiones ya abiertas); esto es la explicación en la puerta.
    unless resource.rol_habilitado?
      sign_out(resource_name)
      render json: { error: mensaje_rol_deshabilitado(resource), modulo_rol_apagado: true },
             status: :forbidden and return
    end

    sign_in(resource_name, resource)
    # JwtCookieMiddleware (initializers/jwt_cookie_middleware.rb) intercepta
    # el Authorization header que Devise JWT añade en la capa Rack y lo convierte
    # a cookie httpOnly para web, o lo deja intacto para X-Mobile-Client.
    render json: {
      id:         resource.id,
      email:      resource.email,
      role:       resource.role,
      club_id:    resource.club_id,
      first_name: resource.first_name,
      last_name:  resource.last_name
    }, status: :ok
  end

  def destroy
    revocar_token
    sign_out(resource_name)
    # El delete DEBE usar el mismo domain que el set, si no el navegador no la borra.
    delete_opts = { path: '/' }
    delete_opts[:domain] = ENV['COOKIE_DOMAIN'] if ENV['COOKIE_DOMAIN'].present?
    response.delete_cookie('jwt_token', delete_opts)
    head :no_content
  end

  private

  # Cerrar sesión DEJA DE VALER el token, no sólo borra la cookie: si alguien se lo llevó, ya no le
  # sirve. Lo hacemos acá y no en el middleware de warden-jwt_auth porque aquel decodifica DESPUÉS
  # de la respuesta y un token inválido (p. ej. firmado con un secreto ya rotado) le hace tirar un
  # 500 que se come el Set-Cookie: la cookie quedaba y el logout fallaba. Acá un token que no se
  # puede leer no tiene nada que revocar, y la cookie se borra igual.
  def revocar_token
    token = request.headers['Authorization'].to_s.sub(/\ABearer /i, '')
    Warden::JWTAuth::TokenRevoker.new.call(token) if token.present?
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    nil
  ensure
    # Que el middleware no lo intente de nuevo (y no reviente con el mismo token).
    request.env.delete('HTTP_AUTHORIZATION')
  end

  def respond_to_on_destroy
    head :no_content
  end
end
