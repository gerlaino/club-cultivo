class SuperAdmin::UsersController < SuperAdmin::BaseController
  def index
    # Los ÚLTIMOS arriba. Ordenado por club y rol, el usuario que acabás de crear caía en el
    # medio de la lista y había que buscarlo: en el panel de plataforma lo que se mira es lo
    # que acaba de pasar, no el padrón histórico.
    users = User.where.not(role: 'super_admin').includes(:club).order(created_at: :desc)
    render json: users.map { |u| serialize_user(u) }
  end

  def create
    club = Club.find(params[:user][:club_id])

    rol = params.dig(:user, :role).to_s

    # El rol tiene que servirle a lo que la organización contrató. Crear un cultivador en una
    # organización sin la suite de Cultivo da de alta a alguien que loguea a una app sin una
    # sola pantalla — y el que lo nota es el cliente, no nosotros.
    if (faltante = club.modulo_faltante_para_rol(rol))
      return render json: { errors: ["#{Club::ROLES_META.dig(rol, :label) || rol} necesita el módulo " \
                                     "#{Club.label_modulo(faltante)}, que esta organización no tiene activo."] },
                    status: :unprocessable_entity
    end

    # El plan también limita los usuarios: crearlos desde el panel de plataforma se salteaba
    # el límite que sí se aplica cuando los crea el club (ver club_users_controller). El cupo
    # es por ROL desde que "5 usuarios" dejó de significar algo.
    enforcer = PlanEnforcer.new(club)
    unless enforcer.puede_crear_usuario?(rol)
      info = enforcer.info
      return render json: PlanEnforcer.error_limite_rol(rol, plan: info[:label],
                                                        tope: enforcer.usuarios_por_rol),
                    status: :payment_required
    end

    user     = club.users.build(user_params)
    # Sin contraseña escrita, se genera una temporal y dictable. Antes caía en una FIJA para toda
    # la plataforma, que además venía precargada en el formulario.
    password = params[:user][:password].presence || User.password_temporal
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

  # `email` es el identificador de LOGIN y `email_personal` el mail real de la persona (ver
  # `User#email_notificacion`). El alta desde el panel sólo aceptaba el primero, así que un
  # usuario creado desde acá nacía sin dirección a la que escribirle: los avisos salían al
  # login, que puede ser inventado, y rebotaban.
  def user_params
    params.require(:user).permit(:email, :email_personal, :first_name, :last_name, :role)
  end

  def user_params_update
    params.require(:user).permit(:email, :email_personal, :first_name, :last_name, :role, :password)
  end

  def serialize_user(u)
    {
      id:         u.id,
      email:      u.email,
      email_personal: u.email_personal,
      role:       u.role,
      first_name: u.first_name,
      last_name:  u.last_name,
      club_id:    u.club_id,
      club_name:  u.club&.name,
      created_at: u.created_at,
    }
  end
end