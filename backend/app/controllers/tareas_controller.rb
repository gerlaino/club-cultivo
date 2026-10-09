class TareasController < ApplicationController
  PENDIENTES_LIMIT = 100

  # UNA TAREA DE MÁS ADELANTE SE PUEDE DAR POR HECHA, CON AVISO (9-oct-2026, Germán; antes se
  # rechazaba). Queda hecha HOY: `fecha_completada` es la de hoy y el calendario la muestra el día
  # en que se hizo, no el programado. `fecha_programada` no se toca a propósito: es la clave con la
  # que el plan reconoce sus tareas, y moverla haría que el plan la volviera a crear ese día.
  #
  # Vive en el backend y no sólo en la UI porque hay varias pantallas que completan tareas
  # (la semana del teléfono, el listado de escritorio, el bloque de tareas del lote): sin
  # `adelantar` contesta 409 `tarea_futura` con el aviso escrito, y la pantalla lo muestra.

  # Cómo se dice en pantalla que una tarea ya se cerró (antes salía el estado crudo: «ya está no
  # realizada»).
  CERRADA_COMO = {
    'completada'   => 'ya se marcó como hecha',
    'no_realizada' => 'ya se marcó que no se hizo',
    'cancelada'    => 'está cancelada',
  }.freeze

  before_action :authenticate_user!
  before_action :check_tareas_role!
  before_action :set_club
  before_action :set_tarea, only: [:show, :update, :destroy, :completar, :no_realizada, :iniciar, :cancelar, :cancelar_serie]
  before_action :authorize_create!, only: [:create]
  # `completar_masivo` NO está acá: completar una tarea es hacer el trabajo, no gestionarlo, y de
  # a una ya lo puede cualquiera que llegue al controller (ver `completar`). Que la misma acción
  # se permitiera de a una y se rechazara en tanda dejaba al manicura tildando su tarea asignada
  # y comiéndose un 403 — con el botón a la vista. El alcance se acota adentro de la acción: quien
  # no gestiona sólo completa LAS SUYAS.
  before_action :authorize_manage!, only: [:update, :destroy]

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
    if @tarea.cerrada?
      return render json: { error: "No se puede completar una tarea #{@tarea.estado}" }, status: :unprocessable_entity
    end

    adelantada = @tarea.programada_a_futuro?
    if adelantada && !adelanta?
      return render json: aviso_adelantar([@tarea]), status: :conflict
    end

    horas = params[:horas_reales]&.to_f
    notas = params[:notas_completado]
    notas = [nota_adelantada(@tarea), notas.presence].compact.join("\n") if adelantada

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

  # POST /api/v1/tareas/:id/no_realizada  { motivo? }
  #
  # «No se hizo»: el par de «Completar», con sus mismas reglas: quien puede completar una tarea
  # puede marcar que no se hizo, una tarea cerrada no se vuelve a cerrar, y una de más adelante
  # todavía no llegó (no se puede no haber hecho algo que no tocaba).
  def no_realizada
    if @tarea.cerrada?
      return render json: { error: "Esa tarea ya está cerrada: #{CERRADA_COMO.fetch(@tarea.estado, @tarea.estado)}." },
                    status: :unprocessable_entity
    end
    if @tarea.programada_a_futuro?
      return render json: { error: 'Esa tarea es para más adelante: todavía no se puede marcar que no se hizo.' },
                    status: :unprocessable_entity
    end
    @tarea.marcar_no_realizada!(motivo: params[:motivo].to_s.strip.first(500))
    render json: serialize_tarea(@tarea)
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

    # Las de más adelante, igual que de a una: con aviso, y quedan hechas hoy.
    seleccionadas = @club.tareas.where(id: ids, estado: %w[pendiente en_progreso])
    futuras = seleccionadas.where('fecha_programada > ?', Time.zone.today)
    if futuras.exists? && !adelanta?
      return render json: aviso_adelantar(futuras.to_a), status: :conflict
    end

    # Quien no gestiona tareas sólo cierra las SUYAS. Esto es un `update_all`: sin el filtro, un
    # id ajeno metido en la lista cerraría la tarea de otro sin pasar por ninguna validación.
    unless puede_gestionar_tareas?
      seleccionadas = seleccionadas.where(asignada_a_id: current_user.id)
    end

    ahora = Time.current
    adelantadas = futuras.to_a
    completadas = seleccionadas
      .update_all(estado: 'completada', fecha_completada: ahora, updated_at: ahora)
    adelantadas.each { |t| t.update_column(:notas_completado, nota_adelantada(t)) }

    # Cero completadas con tareas pedidas no es un éxito silencioso: o ya estaban cerradas o son
    # de otra persona. Sin este mensaje el botón parece no hacer nada.
    if completadas.zero?
      return render json: { error: 'Ninguna de esas tareas se puede completar: ya están cerradas o están asignadas a otra persona.' },
                    status: :unprocessable_entity
    end

    render json: { completadas: completadas }
  end

  # POST /api/v1/tareas/:id/cancelar
  def cancelar
    if @tarea.completada? || @tarea.no_realizada?
      return render json: { error: "No se puede cancelar una tarea #{@tarea.estado.tr('_', ' ')}" }, status: :unprocessable_entity
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

    # Cada tarea va el día en que PASÓ: la hecha, el día en que se hizo (una adelantada no queda
    # en su fecha futura, ni una atrasada en el día que se venció); el resto, el programado.
    hecha = "tareas.estado = 'completada' AND tareas.fecha_completada IS NOT NULL"
    tareas = base.where.not(estado: %w[cancelada])
                 .where("(#{hecha} AND tareas.fecha_completada BETWEEN :t0 AND :t1) OR " \
                        "(NOT (#{hecha}) AND tareas.fecha_programada BETWEEN :d0 AND :d1)",
                        t0: desde.in_time_zone.beginning_of_day, t1: hasta.in_time_zone.end_of_day,
                        d0: desde, d1: hasta)
                 .includes(:asignada_a, :sala, :lote, :origen_plan)
                 .order(:fecha_programada, :prioridad).to_a
    dia_de = ->(t) { t.completada? && t.fecha_completada ? t.fecha_completada.in_time_zone.to_date : t.fecha_programada }
    previstas = previstas_de_planes(desde, hasta)

    dias = (0..6).map do |offset|
      dia = desde + offset
      {
        fecha:      dia,
        dia_semana: I18n.l(dia, format: '%A').capitalize,
        tareas:     tareas.select { |t| dia_de.(t) == dia }.map { |t| serialize_tarea(t) },
        previstas:  previstas.select { |p| p[:fecha_programada] == dia },
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

  def adelanta? = ActiveModel::Type::Boolean.new.cast(params[:adelantar])

  def fecha_corta(fecha) = I18n.l(fecha, format: '%a %-d/%-m')

  def aviso_adelantar(futuras)
    hoy = fecha_corta(Time.zone.today)
    texto = if futuras.size == 1
              "Esta tarea es para el #{fecha_corta(futuras.first.fecha_programada)}. Si la marcás como hecha, " \
                "queda hecha hoy (#{hoy}) y deja de figurar en su fecha."
            else
              "#{futuras.size} de las tareas elegidas son para más adelante. Si las marcás como hechas, " \
                "quedan hechas hoy (#{hoy}) y dejan de figurar en su fecha."
            end
    { codigo: 'tarea_futura', error: texto }
  end

  def nota_adelantada(t) = "Hecha antes de tiempo: era para el #{fecha_corta(t.fecha_programada)}."

  # Lo que los planes tienen programado en la semana y todavía no es una tarea (se crea una semana
  # antes de su día): el calendario lo muestra como previsto, sin acciones. Quien no gestiona
  # tareas ve sólo lo que le va a tocar a él.
  def previstas_de_planes(desde, hasta)
    return [] if hasta <= Time.zone.today

    @club.aplicacion_planes.activos.includes(:plan_trabajo).flat_map do |a|
      Planes::Materializar.pendientes(a, desde: desde, hasta: hasta).filter_map do |oc|
        next if !(current_user.admin? || current_user.super_admin?) && oc.asignada&.id != current_user.id

        obj = a.objetivo
        { clave: "#{a.id}-#{oc.plan_tarea.id}-#{oc.fecha}-#{oc.asignada&.id}", prevista: true,
          titulo: oc.plan_tarea.titulo.presence || oc.plan_tarea.tipo.humanize, tipo: oc.plan_tarea.tipo,
          prioridad: oc.plan_tarea.prioridad, fecha_programada: oc.fecha,
          aparece_el: Planes::Materializar.aparece_el(oc.fecha),
          asignada_a: oc.asignada ? { id: oc.asignada.id, nombre: oc.asignada.nombre_completo } : nil,
          lote: obj.is_a?(Lote) ? { id: obj.id, codigo: obj.codigo } : nil,
          sala: obj.is_a?(Sala) ? { id: obj.id, nombre: obj.nombre } : nil,
          origen_plan: { id: a.plan_trabajo_id, titulo: a.plan_trabajo&.titulo } }
      end
    end.sort_by { |p| [p[:fecha_programada], p[:titulo]] }
  end

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
      :recurrente, :frecuencia, :intervalo, :recurrencia_hasta, :recurrencia_veces,
      :recordatorio
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

  # Gestionar = editar, borrar y cerrar tareas de CUALQUIERA. Hacer el trabajo (completar la
  # propia) no entra acá.
  def puede_gestionar_tareas?
    current_user.admin? || current_user.cultivador? || current_user.supervisor?
  end

  def authorize_manage!
    unless puede_gestionar_tareas?
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
      recordatorio:     t.recordatorio,
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