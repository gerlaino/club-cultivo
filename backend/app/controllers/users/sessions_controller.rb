class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)

    jwt = response.headers.delete('Authorization')&.sub('Bearer ', '')

    payload = {
      id:         resource.id,
      email:      resource.email,
      role:       resource.role,
      club_id:    resource.club_id,
      first_name: resource.first_name,
      last_name:  resource.last_name
    }

    if request.headers['X-Mobile-Client'] == 'true'
      # App nativa: no puede leer httpOnly cookie → devolvemos el token en el body
      payload[:token] = jwt
    else
      # Web SPA: httpOnly cookie, más seguro contra XSS
      set_jwt_cookie(jwt) if jwt.present?
    end

    render json: payload, status: :ok
  end

  def destroy
    sign_out(resource_name)
    clear_jwt_cookie
    head :no_content
  end

  private

  def set_jwt_cookie(token)
    response.set_cookie('jwt_token', {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: Rails.env.production? ? :Strict : :Lax,
      path: '/',
      expires: 12.hours.from_now
    })
  end

  def clear_jwt_cookie
    response.delete_cookie('jwt_token', { path: '/' })
  end

  def respond_to_on_destroy
    head :no_content
  end
end
