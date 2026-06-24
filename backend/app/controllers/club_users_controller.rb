class ClubUsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_user, only: [:show, :update, :destroy, :reset_password, :salas_asignadas, :asignar_sala, :desasignar_sala, :sedes_asignadas, :asignar_sede, :desasignar_sede, :stats, :recibir_caja]

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
    nuevo_rol = params.dig(:user, :role).to_s

    # Guard: un delivery con despachos pendientes no puede cambiar de rol hasta
    # reasignarlos (si no, quedarían asignados a alguien que ya no es repartidor).
    if nuevo_rol.present? && nuevo_rol != @user.role && @user.role == 'delivery'
      pend = despachos_pendientes_de(@user)
      if pend > 0
        return render json: {
          errors: ["#{@user.first_name} tiene #{pend} despacho#{'s' if pend != 1} pendiente#{'s' if pend != 1} asignado#{'s' if pend != 1}. Reasignalos antes de cambiarle el rol."]
        }, status: :unprocessable_entity
      end
    end

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

  # GET /usuarios/:id/stats?anio=&mes=
  # Estadísticas del usuario en el mes: horas trabajadas + métricas según su rol
  # (producción de manicura, despachos de delivery, dispensaciones por medio de pago).
  def stats
    anio = (params[:anio] || Date.current.year).to_i
    mes  = (params[:mes]  || Date.current.month).to_i
    ini  = Date.new(anio, mes, 1)
    rango_fecha = ini..ini.end_of_month
    rango_ts    = ini.beginning_of_day..ini.end_of_month.end_of_day
    club = current_user.club

    # Horas (planilla)
    jornadas = club.jornadas_laborales.where(user_id: @user.id, fecha: rango_fecha)
    horas = {
      total: jornadas.sum(&:horas).round(2),
      dias:  jornadas.count,
    }

    # Producción de manicura
    pesajes = PesajeManicura.where(club_id: club.id, manicurador_id: @user.id, created_at: rango_ts)
    produccion = {
      pesajes: pesajes.count,
      gramos:  pesajes.sum(:peso_total_g).to_f.round(2),
    }

    # Despachos (delivery). @user ya está scopeado al club (set_user), así que
    # filtrar por delivery_id/user_id es tenant-safe aunque dispensaciones no tenga club_id.
    despachos_scope = Dispensacion.where(delivery_id: @user.id, fecha_dispensacion: rango_fecha)
    despachos = {
      total:      despachos_scope.count,
      entregados: despachos_scope.where(estado_envio: 'entregado').count,
      fallidos:   despachos_scope.where(estado_envio: 'fallido').count,
    }

    # Dispensaciones realizadas por el usuario, por medio de pago
    disp_scope = Dispensacion.no_canceladas.where(user_id: @user.id, fecha_dispensacion: rango_fecha)
    dispensaciones = {
      total:        disp_scope.count,
      por_medio:    disp_scope.group(:medio_pago).count,
      gramos:       disp_scope.sum(:cantidad).to_f.round(2),
    }

    # Caja del delivery: efectivo cobrado en entregas todavía en tránsito (no rendido).
    # Es un saldo vivo (todo el histórico pendiente), no del mes.
    en_transito = Cobro.efectivo_en_transito.del_delivery(@user.id).where(club_id: club.id)
    caja_delivery = {
      efectivo_en_mano: en_transito.sum(:monto_ars).to_f,
      cobros_pendientes: en_transito.count,
      en_viaje: Dispensacion.where(delivery_id: @user.id, estado_envio: 'en_viaje').count,
    }

    render json: {
      anio: anio, mes: mes,
      usuario: { id: @user.id, nombre: @user.nombre_completo, rol: @user.role },
      horas: horas,
      produccion: produccion,
      despachos: despachos,
      dispensaciones: dispensaciones,
      caja_delivery: caja_delivery,
    }
  end

  # POST /usuarios/:id/recibir_caja
  # El admin recibe el efectivo en tránsito del delivery: asienta los ingresos y
  # marca los cobros como rendidos.
  def recibir_caja
    res = Dispensaciones::RecibirCajaDelivery.call(
      delivery: @user, club: current_user.club, receptor: current_user)
    if res.ok?
      render json: { recibido_ars: res.total.to_f, cobros: res.cantidad }
    else
      render json: { error: res.error }, status: :unprocessable_entity
    end
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

  # Despachos (dispensaciones con envío) pendientes o en viaje asignados al usuario.
  def despachos_pendientes_de(user)
    Dispensacion.joins(stock: :sede)
                .where(sedes: { club_id: current_user.club_id })
                .where(delivery_id: user.id, con_envio: true, estado_envio: %w[pendiente en_viaje])
                .count
  end
end


