class TareasController < ApplicationController
  PENDIENTES_LIMIT = 100

  # El calendario no se adelanta. Si el trabajo se hizo antes de lo programado, se registra como
  # lo que fue —una tarea hecha HOY— y la programada se cancela cuando llegue su día, con la
  # observación. Así la fecha de cada registro sigue siendo la fecha real en que se trabajó.
  #
  # Vive en el backend y no sólo en la UI porque hay varias pantallas que completan tareas
  # (la semana del teléfono, el listado de escritorio, el bloque de tareas del lote) y cada una
  # traía su propio criterio: la del lote dejaba marcar una futura tocándola a mano.
  MSG_TAREA_FUTURA = 'Esa tarea está programada para más adelante y todavía no se puede dar por ' \
                     'hecha. Si el trabajo ya se hizo, cargá una tarea de hoy describiéndolo y ' \
                     'cancelá la programada cuando llegue su día.'.freeze

  before_action :authenticate_user!
  before_action :check_tareas_role!
  before_action :set_club
  before_action :set_tarea, only: [:show, :update, :destroy, :completar, :iniciar, :cancelar, :cancelar_serie]
  before_action :authorize_create!, only: [:create]
  before_action :authorize_manage!, only: [:update, :destroy, :completar_masivo]

  # GET /api/v1/tareas
  # Soporta filtros: estado, asignada_a_id, sala_id, lote_id, tipo, fecha_desde, fecha_hasta, scope
  def index
    tareas = @club.tareas.includes(:asignada_a, :creada_por, :sala, :lote, :plant, :origen_plan)

    # Supervisor solo ve tareas de sus sedes
    if current_user.supervisor?
      salas_ids = current_user.salas_ids_en_sedes_asignadas
      tareas = tareas.where(sala_id: salas_ids)
    end

    # scope especial para dashboard del cultivador / supervisor
    if params[:scope] == 'mias'
      tareas = tareas.asignadas_a(current_user.id)
    elsif params[:scope] == 'hoy'
      tareas = tareas.asignadas_a(current_user.id).de_hoy
    elsif params[:scope] == 'activas_mias'
      tareas = tareas.asignadas_a(current_user.id).activas
    end

    tareas = tareas.where(estado: params[:estado])           if params[:estado].present?
    tareas = tareas.where(asignada_a_id: params[:asignada_a_id]) if params[:asignada_a_id].present?
    tareas = tareas.where(sala_id: params[:sala_id])         if params[:sala_id].present?
    tareas = tareas.where(lote_id: params[:lote_id])         if params[:lote_id].present?
    tareas = tareas.where(tipo: params[:tipo])               if params[:tipo].present?
    tareas = tareas.where(prioridad: params[:prioridad])     if params[:prioridad].present?

    if params[:fecha_desde].present?
      tareas = tareas.where('fecha_programada >= ?', params[:fecha_desde])
    end
    if params[:fecha_hasta].present?
      tareas = tareas.where('fecha_programada <= ?', params[:fecha_hasta])
    end

    tareas = tareas.order(created_at: :desc)

    render json: tareas.map { |t| serialize_tarea(t) }
  end

  # GET /api/v1/tareas/dashboard
  # Resumen para el dashboard del cultivador
  def dashboard
    base = if current_user.admin? || current_user.super_admin?
      @club.tareas
    else
      @club.tareas.asignadas_a(current_user.id)
    end

    # Listado accionable de /tareas: lo que hay para hacer HOY (vencidas + de hoy +
    # sin fecha). Mismo scope que stats.pendientes, así el KPI y la lista coinciden.
    # Acotado a 100 — con stats.pendientes el front avisa si se truncó.
    pendientes = base.pendientes_al_dia
                     .includes(:asignada_a, :sala, :lote, :origen_plan)
                     .order(Arel.sql('fecha_programada ASC NULLS LAST'))
                     .por_prioridad
                     .limit(PENDIENTES_LIMIT)

    render json: {
      hoy: base.de_hoy.order(created_at: :desc).map { |t| serialize_tarea(t) },
      pendientes: pendientes.map { |t| serialize_tarea(t) },
      vencidas: base.vencidas.por_prioridad.limit(5).map { |t| serialize_tarea(t) },
      proximas: base.proximas.where.not(fecha_programada: Time.zone.today)
                    .por_prioridad.limit(10).map { |t| serialize_tarea(t) },
      stats: {
        pendientes: base.pendientes_al_dia.count,
        en_progreso: base.en_progreso.count,
        completadas_hoy: base.completadas.where(fecha_completada: Time.zone.today.all_day).count,
        vencidas: base.vencidas.count
      }
    }
  end


  # GET /api/v1/tareas/:id
  def show
    render json: serialize_tarea(@tarea)
  end

  # POST /api/v1/tareas
  def create
    tarea = @club.tareas.build(tarea_params)
    tarea.creada_por = current_user

    # Cultivador solo puede asignarse a sí mismo
    if current_user.cultivador?
      tarea.asignada_a_id = current_user.id
    end

    # Supervisor solo puede crear tareas en salas de sus sedes asignadas
    if current_user.supervisor? && tarea.sala_id.present?
      unless current_user.salas_ids_en_sedes_asignadas.include?(tarea.sala_id.to_i)
        return render json: { error: 'Solo podés crear tareas en salas de tus sedes asignadas' }, status: :forbidden
      end
    end

    if tarea.save
      serie_count = tarea.recurrente? ? tarea.generar_serie!.length : 0
      render json: serialize_tarea(tarea).merge(serie_creada: serie_count), status: :created
    else
      render json: { errors: tarea.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/tareas/:id
  def update
    attrs = tarea_params

    # Proteger campos críticos en tareas completadas
    if @tarea.completada?
      attrs = attrs.except(:titulo, :tipo, :asignada_a_id, :lote_id, :sala_id)
    end

    # Cultivador no puede reasignar
    attrs = attrs.except(:asignada_a_id) if current_user.cultivador?

    if @tarea.update(attrs)
      render json: serialize_tarea(@tarea)
    else
      render json: { errors: @tarea.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/tareas/:id/iniciar
  def iniciar
    unless @tarea.pendiente?
      return render json: { error: 'Solo se pueden iniciar tareas pendientes' }, status: :unprocessable_entity
    end

    @tarea.iniciar!(current_user)
    render json: serialize_tarea(@tarea)
  end

  # POST /api/v1/tareas/:id/completar
  def completar
    if @tarea.completada? || @tarea.cancelada?
      return render json: { error: "No se puede completar una tarea #{@tarea.estado}" }, status: :unprocessable_entity
    end

    if @tarea.programada_a_futuro?
      return render json: { error: MSG_TAREA_FUTURA }, status: :unprocessable_entity
    end

    horas = params[:horas_reales]&.to_f
    notas = params[:notas_completado]

    @tarea.completar!(horas_reales: horas, notas: notas)

    # Tarea de trasplante con maceta cargada → registra el trasplante en el lote
    # (PlantActivity + actualiza la maceta), igual que el botón "Registrar trasplante".
    if @tarea.tipo == 'trasplante' && @tarea.lote_id && params[:maceta_destino_l].present?
      Lotes::RegistrarTrasplante.call(
        lote: @tarea.lote, usuario: current_user,
        destino: params[:maceta_destino_l], origen: params[:maceta_origen_l],
        fecha: @tarea.fecha_completada&.to_date || Date.current)
    end

    render json: {
      tarea: serialize_tarea(@tarea),
      tiene_horas_para_lote: @tarea.tiene_horas_para_lote?
    }
  end

  # POST /api/v1/tareas/completar_masivo
  # Body: { ids: [1,2,3] } — marca como completadas las tareas pendientes/en_progreso.
  # Pensado para registrar de un saque lo ya hecho (p. ej. tras aplicar un plan con
  # fecha pasada). No pide horas: es un registro retroactivo.
  def completar_masivo
    ids = Array(params[:ids]).map(&:to_i).uniq.reject(&:zero?)
    if ids.empty?
      return render json: { error: 'Seleccioná al menos una tarea' }, status: :unprocessable_entity
    end

    # Una tarea de mañana no se completa hoy — ni de a una ni en tanda. El registro retroactivo
    # es para ponerse al día con lo atrasado, no para adelantar el calendario.
    seleccionadas = @club.tareas.where(id: ids, estado: %w[pendiente en_progreso])
    if seleccionadas.where('fecha_programada > ?', Time.zone.today).exists?
      return render json: { error: MSG_TAREA_FUTURA }, status: :unprocessable_entity
    end

    ahora = Time.current
    completadas = seleccionadas
      .update_all(estado: 'completada', fecha_completada: ahora, updated_at: ahora)

    render json: { completadas: completadas }
  end

  # POST /api/v1/tareas/:id/cancelar
  def cancelar
    if @tarea.completada?
      return render json: { error: 'No se puede cancelar una tarea completada' }, status: :unprocessable_entity
    end

    @tarea.update!(estado: 'cancelada')
    render json: serialize_tarea(@tarea)
  end

  # DELETE /api/v1/tareas/:id
  def destroy
    # Las completadas solo las puede borrar un admin (corrección de historial).
    if @tarea.completada? && !current_user.admin?
      return render json: { error: 'Solo un administrador puede eliminar tareas completadas' }, status: :unprocessable_entity
    end
    @tarea.destroy
    head :no_content
  end

  # GET /api/v1/tareas/semana?desde=YYYY-MM-DD
  def semana
    desde = params[:desde].present? ? Date.parse(params[:desde]) : Date.current.beginning_of_week(:monday)
    hasta = desde + 6.days

    base = if current_user.admin? || current_user.super_admin?
      @club.tareas
    else
      @club.tareas.asignadas_a(current_user.id)
    end

    tareas = base.where(fecha_programada: desde..hasta)
                 .where.not(estado: %w[cancelada])
                 .includes(:asignada_a, :sala, :lote, :origen_plan)
                 .order(:fecha_programada, :prioridad)

    dias = (0..6).map do |offset|
      dia = desde + offset
      {
        fecha:      dia,
        dia_semana: I18n.l(dia, format: '%A').capitalize,
        tareas:     tareas.select { |t| t.fecha_programada == dia }.map { |t| serialize_tarea(t) }
      }
    end

    render json: { desde: desde, hasta: hasta, dias: dias }
  end

  # DELETE /api/v1/tareas/:id/cancelar_serie
  def cancelar_serie
    root = @tarea.parent_tarea_id ? @tarea.parent_tarea : @tarea
    canceladas = Tarea.where(parent_tarea_id: root.id, estado: %w[pendiente en_progreso]).count
    Tarea.where(parent_tarea_id: root.id, estado: %w[pendiente en_progreso]).update_all(estado: 'cancelada')
    canceladas += 1 if root.pendiente? || root.en_progreso?
    root.update(estado: 'cancelada') if root.pendiente? || root.en_progreso?
    render json: { canceladas: canceladas }
  end

  private

  def set_club
    @club = current_user.club
  end

  def set_tarea
    @tarea = @club.tareas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tarea no encontrada' }, status: :not_found
  end

  def tarea_params
    params.require(:tarea).permit(
      :titulo, :descripcion, :tipo, :estado, :prioridad,
      :asignada_a_id, :sala_id, :lote_id, :plant_id,
      :fecha_programada, :horas_estimadas, :horas_reales,
      :notas_completado, :horas_aplicadas_al_lote,
      :recurrente, :frecuencia, :intervalo, :recurrencia_hasta, :recurrencia_veces
    )
  end

  def check_tareas_role!
    blocked = %w[abogado paciente delivery]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def authorize_create!
    unless current_user.admin? || current_user.cultivador? || current_user.supervisor?
      render json: { error: 'Sin permiso para crear tareas' }, status: :forbidden
    end
  end

  def authorize_manage!
    unless current_user.admin? || current_user.cultivador? || current_user.supervisor?
      render json: { error: 'Sin permiso para modificar esta tarea' }, status: :forbidden
    end
  end

  def serialize_tarea(t)
    {
      id: t.id,
      titulo: t.titulo,
      descripcion: t.descripcion,
      tipo: t.tipo,
      estado: t.estado,
      prioridad: t.prioridad,
      fecha_programada: t.fecha_programada,
      fecha_completada: t.fecha_completada,
      horas_estimadas: t.horas_estimadas,
      horas_reales: t.horas_reales,
      notas_completado: t.notas_completado,
      horas_aplicadas_al_lote: t.horas_aplicadas_al_lote,
      tiene_horas_para_lote: t.tiene_horas_para_lote?,
      vencida: t.vencida?,
      creada_por: t.creada_por ? { id: t.creada_por.id, nombre: t.creada_por.nombre_completo } : nil,
      asignada_a: t.asignada_a ? { id: t.asignada_a.id, nombre: t.asignada_a.nombre_completo } : nil,
      sala: t.sala ? { id: t.sala.id, nombre: t.sala.nombre, sede_id: t.sala.sede_id } : nil,
      lote: t.lote ? { id: t.lote.id, codigo: t.lote.codigo } : nil,
      plant: t.plant ? { id: t.plant.id, codigo_qr: t.plant.codigo_qr, nombre: t.plant.nombre } : nil,
      recurrente:        t.recurrente,
      frecuencia:        t.frecuencia,
      parent_tarea_id:   t.parent_tarea_id,
      origen_plan_id:    t.origen_plan_id,
      origen_plan_titulo: t.origen_plan_titulo,
      origen_plan:       t.origen_plan ? { id: t.origen_plan.id, titulo: t.origen_plan.titulo } : nil,
      created_at:        t.created_at,
      updated_at:        t.updated_at
    }
  end
end