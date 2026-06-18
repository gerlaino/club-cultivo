class ClubUsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_user, only: [:show, :update, :destroy, :reset_password, :salas_asignadas, :asignar_sala, :desasignar_sala, :sedes_asignadas, :asignar_sede, :desasignar_sede]

  # GET /usuarios
  def index
    q   = params[:query].to_s.strip.downcase
    rel = User.where(club_id: current_user.club_id)

    if q.present?
      rel = rel.where(
        "lower(first_name) LIKE :q OR lower(last_name) LIKE :q OR lower(email) LIKE :q",
        q: "%#{q}%"
      )
    end

    if params[:roles].present?
      rel = rel.where(role: Array(params[:roles]))
    elsif params[:role].present?
      rel = rel.where(role: params[:role])
    end

    users = rel.order("created_at DESC")
    render json: { data: users.map { |u|
      u.as_json(only: [:id, :email, :first_name, :last_name, :role, :created_at, :updated_at])
    } }
  end

  # GET /usuarios/:id
  def show
    render json: { data: @user.as_json(only: [:id, :email, :first_name, :last_name, :role, :created_at, :updated_at]) }
  end

  # POST /usuarios
  def create
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_usuario?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('usuarios', info[:limites][:usuarios]), status: :payment_required
    end

    # No se pueden dar de alta usuarios operativos hasta que el club tenga al
    # menos una sede: esos roles se asignan a sedes/salas y, sin sede, loguearían
    # a una app vacía (inconsistencia de onboarding). El admin sí puede crearse.
    nuevo_rol = params.dig(:user, :role).to_s
    unless nuevo_rol == 'admin' || current_user.club.sedes.exists?
      return render json: { errors: ['Creá al menos una sede antes de dar de alta usuarios operativos.'] }, status: :unprocessable_entity
    end

    user = User.new(user_params)
    user.club_id = current_user.club_id

    # Si no se provee password, generar uno temporal y mandar reset
    send_reset = params.dig(:user, :password).blank?
    if send_reset
      tmp_password = SecureRandom.base64(12)
      user.password = tmp_password
      user.password_confirmation = tmp_password
    end

    if user.save
      user.send_reset_password_instructions if send_reset
      render json: { data: user.as_json(only: [:id, :email, :first_name, :last_name, :role]) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /usuarios/:id
  def update
    if @user.update(user_params)
      render json: { data: @user.as_json(only: [:id, :email, :first_name, :last_name, :role]) }
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /usuarios/:id
  def destroy
    if @user.id == current_user.id
      return render json: { errors: ['No podés eliminarte a vos mismo.'] }, status: :unprocessable_entity
    end

    # opcional: impedir borrar super_admin si quien borra no es super_admin
    if @user.role == 'super_admin' && !current_user.admin?
      return render json: { errors: ['No autorizado para eliminar a un super_admin.'] }, status: :forbidden
    end

    @user.destroy!
    head :no_content
  end


  # POST /usuarios/:id/reset_password
  def reset_password
    @user.send_reset_password_instructions
    head :no_content
  end

  def salas_asignadas
    salas = @user.salas_asignadas.includes(:sede)
    render json: salas.map { |s| { id: s.id, nombre: s.nombre, sede: s.sede ? { id: s.sede.id, nombre: s.sede.nombre } : nil } }
  end

  def asignar_sala
    sala = current_user.club.salas.find(params[:sala_id])
    if @user.manicura?
      @user.sala_cultivadores.destroy_all
    end
    SalaCultivador.find_or_create_by!(sala: sala, user: @user)
    render json: { message: "Sala asignada correctamente" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def desasignar_sala
    sala = current_user.club.salas.find(params[:sala_id])
    SalaCultivador.find_by(sala: sala, user: @user)&.destroy
    render json: { message: "Sala desasignada correctamente" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def sedes_asignadas
    render json: @user.sedes_asignadas.map { |s| { id: s.id, nombre: s.nombre, tipo: s.tipo } }
  end

  def asignar_sede
    sede = current_user.club.sedes.find(params[:sede_id])
    UserSede.find_or_create_by!(sede: sede, user: @user)
    render json: { message: "Sede asignada correctamente" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sede no encontrada' }, status: :not_found
  end

  def desasignar_sede
    sede = current_user.club.sedes.find(params[:sede_id])
    UserSede.find_by(sede: sede, user: @user)&.destroy
    render json: { message: "Sede desasignada correctamente" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sede no encontrada' }, status: :not_found
  end

  private

  def set_user
    @user = User.where(club_id: current_user.club_id).find(params[:id])
  end

  def require_admin!
    head :forbidden unless current_user.admin?
  end

  # Solo campos que EXISTEN en tu schema
  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :role, :password, :password_confirmation)
  end
end


