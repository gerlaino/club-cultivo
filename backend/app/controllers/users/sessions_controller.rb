class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
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
    sign_out(resource_name)
    # El delete DEBE usar el mismo domain que el set, si no el navegador no la borra.
    delete_opts = { path: '/' }
    delete_opts[:domain] = ENV['COOKIE_DOMAIN'] if ENV['COOKIE_DOMAIN'].present?
    response.delete_cookie('jwt_token', delete_opts)
    head :no_content
  end

  private

  def respond_to_on_destroy
    head :no_content
  end
end
