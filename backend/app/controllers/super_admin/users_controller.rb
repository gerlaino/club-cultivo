class SuperAdmin::UsersController < SuperAdmin::BaseController
  def index
    users = User.where.not(role: 'super_admin').includes(:club).order(:club_id, :role)
    render json: users.map { |u| serialize_user(u) }
  end

  def create
    club = Club.find(params[:user][:club_id])
    user = club.users.build(user_params)
    user.password = params[:user][:password].presence || '123456Aa'

    if user.save
      render json: serialize_user(user), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    user = User.find(params[:id])
    if user.update(user_params_update)
      render json: serialize_user(user)
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find(params[:id])
    return render json: { error: 'No podés eliminar un super_admin' }, status: :forbidden if user.super_admin?
    user.destroy
    head :no_content
  end

  private

  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :role)
  end

  def user_params_update
    params.require(:user).permit(:email, :first_name, :last_name, :role, :password)
  end

  def serialize_user(u)
    {
      id:         u.id,
      email:      u.email,
      role:       u.role,
      first_name: u.first_name,
      last_name:  u.last_name,
      club_id:    u.club_id,
      club_name:  u.club&.name,
      created_at: u.created_at,
    }
  end
end