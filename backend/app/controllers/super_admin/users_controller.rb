class SuperAdmin::UsersController < SuperAdmin::BaseController
  def index
    users = User.where.not(role: 'super_admin').includes(:club).order(:club_id, :role)
    render json: users.map { |u| serialize_user(u) }
  end

  def create
    club = Club.find(params[:user][:club_id])

    # El plan también limita los usuarios: crearlos desde el panel de plataforma se salteaba
    # el límite que sí se aplica cuando los crea el club (ver club_users_controller).
    enforcer = PlanEnforcer.new(club)
    unless enforcer.puede_crear_usuario?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('usuarios', info[:limites][:usuarios], plan: info[:label]),
                    status: :payment_required
    end

    user     = club.users.build(user_params)
    password = params[:user][:password].presence || Club::PASSWORD_DEFAULT
    user.password = password

    if user.save
      # En claro: es temporal y hay que poder dictársela a quien va a usarla.
      render json: serialize_user(user).merge(password_inicial: password), status: :created
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