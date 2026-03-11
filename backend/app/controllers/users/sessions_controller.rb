class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)

    render json: {
      id: resource.id,
      email: resource.email,
      role: resource.role,
      club_id: resource.club_id,
      first_name: resource.first_name,
      last_name: resource.last_name
    }, status: :ok
  end

  def destroy
    sign_out(resource_name)
    head :no_content
  end

  private

  def respond_to_on_destroy
    head :no_content
  end
end

