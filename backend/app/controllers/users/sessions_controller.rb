class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)

    render json: {
      id: resource.id,
      email: resource.email,
      role: resource.role,
      club_id: resource.club_id
    }, status: :ok
  end

  def destroy
    sign_out(resource_name)
    head :no_content
  end

  def update
    user = current_user # o User.find(params[:id]) si es admin
    if user.update(user_params)
      render json: user.as_json(
        only: %i[id email role club_id first_name last_name dni birthdate phone avatar_url created_at updated_at]
      )
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end


  private

  # Devise por JSON: que no redirija en errores
  def respond_to_on_destroy
    head :no_content
  end
end

