class ClubUsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_user, only: [:show, :update, :destroy, :reset_password, :salas_asignadas, :asignar_sala, :desasignar_sala, :sedes_asignadas, :asignar_sede, :desasignar_sede, :stats, :auditorias, :recibir_caja]

  # GET /usuarios
  def index
    q   = params[:query].to_s.strip.downcase
    rel = User.where(club_id: current_user.club_id).del_equipo

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
    else
      # Sin filtro explícito esto es el listado de "equipo": el paciente tiene su propia
      # ficha y no es personal de la organización, aunque comparta la tabla `users`.
      rel = rel.where.not(role: 'paciente')
    end

    users = rel.order("created_at DESC")
    render json: { data: users.map { |u|
      u.as_json(only: [:id, :email, :email_personal, :first_name, :last_name, :role, :created_at, :updated_at])
    } }
  end

  # GET /usuarios/:id
  def show
    render json: { data: @user.as_json(only: [:id, :email, :email_personal, :first_name, :last_name, :role, :created_at, :updated_at]) }
  end

  # POST /usuarios
  def create
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_usuario?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('usuarios', info[:limites][:usuarios], plan: info[:label]), status: :payment_required
    end

    # No se pueden dar de alta usuarios operativos hasta que el club tenga al
    # menos una sede: esos roles se asignan a sedes/salas y, sin sede, loguearían
    # a una app vacía (inconsistencia de onboarding). El admin sí puede crearse.
    nuevo_rol = params.dig(:user, :role).to_s

    # Sólo los roles que la pantalla ofrece. No alcanza con sacarlos del formulario: el endpoint
    # acepta lo que le manden, y un rol no ofrecido entraría igual por la API. Mismo criterio que
    # el alta de club (`Club::ROLES_ALTA`).
    # `roles_para_alta` y no la constante: delivery sólo se ofrece si la organización tiene el
    # módulo. Crear un repartidor sin Delivery daría de alta a alguien que no puede entrar.
    unless current_user.club.roles_para_alta.include?(nuevo_rol)
      motivo = if Club::ROLES_ALTA_CLUB.include?(nuevo_rol)
                 "El módulo #{Club::ADDONS.dig(Club::MODULO_POR_ROL_OPCIONAL[nuevo_rol], :label) || nuevo_rol} " \
                 'no está activo en esta organización.'
               else
                 "El rol #{nuevo_rol.presence || '(vacío)'} no se puede asignar desde acá."
               end
      return render json: { errors: [motivo] }, status: :unprocessable_entity
    end

    unless nuevo_rol == 'admin' || current_user.club.sedes.exists?
      return render json: { errors: ['Creá al menos una sede antes de dar de alta usuarios operativos.'] }, status: :unprocessable_entity
    end

    user = User.new(user_params)
    user.club_id = current_user.club_id

    # Contraseña inicial: SIEMPRE generada acá y distinta para cada uno. El frontend mandaba
    # una fija ('123456Aa') para todos, así que todo usuario de todo club nacía con la misma
    # clave conocida. Se ignora cualquier password que venga del cliente.
    tmp_password = User.password_temporal
    user.password = user.password_confirmation = tmp_password

    if user.save
      # El mail es la vía cómoda, no la única: si el club no tiene SMTP nunca llega y nadie se
      # entera. La contraseña se devuelve para que el admin pueda dársela en mano.
      enviado = enviar_instrucciones(user)
      render json: {
        data: user.as_json(only: [:id, :email, :email_personal, :first_name, :last_name, :role]),
        credenciales: { email: user.email, password_inicial: tmp_password, mail_enviado: enviado },
      }, status: :created
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
      render json: { data: @user.as_json(only: [:id, :email, :email_personal, :first_name, :last_name, :role]) }
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
  # POST /usuarios/:id/reset_password
  # El caso de uso más común de esta sección —"me olvidé la contraseña"— y no estaba
  # enchufado a ninguna pantalla. Genera una clave nueva, la devuelve para poder dictarla,
  # y manda el mail si el club tiene correo configurado.
  def reset_password
    nueva = User.password_temporal
    @user.update!(password: nueva, password_confirmation: nueva)
    enviado = enviar_instrucciones(@user)

    render json: {
      email: @user.email, password_inicial: nueva, mail_enviado: enviado,
    }
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

  # GET /usuarios/:id/auditorias?page=&per_page=&tipo=&desde=&hasta=
  # Rastro read-only de lo que hizo el usuario (crear/editar/eliminar) sobre registros
  # auditados. Filtrable por tipo y rango de fechas; paginado, más recientes primero.
  # Solo admin (require_admin!).
  def auditorias
    page     = [params[:page].to_i, 1].max
    per_page = [10, 25, 50].include?(params[:per_page].to_i) ? params[:per_page].to_i : 10

    scope = Auditoria.where(user_id: @user.id, club_id: current_user.club_id)
    scope = scope.where(auditable_type: params[:tipo]) if params[:tipo].present?
    if (desde = fecha_param(params[:desde]))
      scope = scope.where('auditorias.created_at >= ?', desde.beginning_of_day)
    end
    if (hasta = fecha_param(params[:hasta]))
      scope = scope.where('auditorias.created_at <= ?', hasta.end_of_day)
    end
    scope = scope.recientes

    total     = scope.count
    registros = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data:        registros.map { |a| serialize_auditoria(a) },
      page:        page,
      per_page:    per_page,
      total:       total,
      total_pages: (total.to_f / per_page).ceil,
      has_more:    page * per_page < total,
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

  # Devuelve si el mail salió de verdad. Un fallo de SMTP no puede tumbar el alta: el usuario
  # ya está creado y el admin tiene la contraseña en pantalla.
  def enviar_instrucciones(user)
    return false unless current_user.club.smtp_configured?
    user.send_reset_password_instructions
    true
  rescue StandardError => e
    Rails.logger.warn("[usuarios] no se pudo enviar el mail a #{user.email}: #{e.message}")
    false
  end

  def set_user
    # `del_equipo`: por acá no se toca la cuenta de un paciente. Sin el scope, un admin podía
    # editarla, resetearle la clave o BORRARLA desde los endpoints de equipo, dejando el
    # `paciente.user_id` colgado. Esa cuenta se gestiona desde la ficha del paciente.
    @user = User.where(club_id: current_user.club_id).del_equipo.find(params[:id])
  end

  # ── Auditoría (rastro read-only) ──────────────────────────────
  TIPOS_AUDITABLE = {
    'Lote' => 'Lote', 'Plant' => 'Planta', 'Stock' => 'Stock', 'Dispensacion' => 'Dispensación',
    'Paciente' => 'Paciente', 'User' => 'Usuario', 'Reserva' => 'Reserva',
  }.freeze
  # Campos internos que no tiene sentido mostrar en el diff.
  CAMPOS_OCULTOS  = %w[id created_at updated_at deleted_at club_id].freeze

  def serialize_auditoria(a)
    {
      id:          a.id,
      accion:      a.accion, # crear | actualizar | eliminar
      tipo:        TIPOS_AUDITABLE[a.auditable_type] || a.auditable_type,
      registro_id: a.auditable_id,
      fecha:       a.created_at,
      # Solo en "actualizar" mostramos el antes→después; crear/eliminar se explican solos.
      cambios:     a.accion == 'actualizar' ? formato_cambios(a.cambios) : [],
    }
  end

  # Parsea "YYYY-MM-DD" a Date; nil si viene vacío o inválido (no rompe el filtro).
  def fecha_param(valor)
    return nil if valor.blank?

    Date.parse(valor.to_s)
  rescue ArgumentError
    nil
  end

  # {"campo" => [de, a]} (saved_changes) → [{campo, de, a}], salteando internos.
  def formato_cambios(cambios)
    (cambios || {}).except(*CAMPOS_OCULTOS).filter_map do |campo, valores|
      next unless valores.is_a?(Array) && valores.size == 2

      { campo: campo, de: valores[0], a: valores[1] }
    end
  end

  def require_admin!
    head :forbidden unless current_user.admin?
  end

  # Solo campos que EXISTEN en tu schema
  def user_params
    params.require(:user).permit(:email, :email_personal, :first_name, :last_name, :role, :password, :password_confirmation)
  end

  # Despachos (dispensaciones con envío) pendientes o en viaje asignados al usuario.
  def despachos_pendientes_de(user)
    Dispensacion.joins(stock: :sede)
                .where(sedes: { club_id: current_user.club_id })
                .where(delivery_id: user.id, con_envio: true, estado_envio: %w[pendiente en_viaje])
                .count
  end
end


