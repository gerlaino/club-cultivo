class AplicacionPlanesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :authorize_admin_or_supervisor!
  before_action :set_club
  before_action :set_aplicacion, only: [:show, :destroy, :cancelar]

  # GET /api/aplicacion_planes
  def index
    aplicaciones = @club.aplicacion_planes
      .includes(:plan_trabajo, :aplicado_por)
      .recientes

    aplicaciones = aplicaciones.where(estado: params[:estado])               if params[:estado].present?
    aplicaciones = aplicaciones.where(objetivo_tipo: params[:objetivo_tipo]) if params[:objetivo_tipo].present?
    aplicaciones = aplicaciones.where(objetivo_id: params[:objetivo_id])     if params[:objetivo_id].present?

    render json: aplicaciones.map { |a| serialize(a) }
  end

  # GET /api/aplicacion_planes/:id
  def show
    render json: serialize_full(@aplicacion)
  end

  # GET /api/aplicacion_planes/preview?plan_trabajo_id=&fecha_inicio=&objetivo_tipo=&objetivo_id=
  #
  # La misma cuenta que se usa al aplicar: la pantalla no calcula fechas por su cuenta.
  def preview
    plan     = @club.plan_trabajos.find(params[:plan_trabajo_id])
    fecha    = Date.parse(params[:fecha_inicio].to_s)
    objetivo = objetivo_de(params[:objetivo_tipo], params[:objetivo_id])
    cal      = Planes::Calendario.new(plan: plan, fecha_inicio: fecha, objetivo: objetivo)
    hoy      = Time.zone.today
    tareas   = cal.ocurrencias.map do |oc|
      { plan_tarea_id: oc.plan_tarea.id, titulo: oc.plan_tarea.titulo.presence || oc.plan_tarea.tipo.humanize,
        tipo: oc.plan_tarea.tipo, fecha: oc.fecha, en_el_pasado: oc.fecha < hoy,
        aparece_el: (Planes::Materializar.aparece_el(oc.fecha, hoy: hoy) unless oc.fecha < hoy),
        responsable: oc.asignada&.nombre_completo }
    end
    render json: { tareas: tareas, total: tareas.count { |t| !t[:en_el_pasado] },
                   en_el_pasado: tareas.count { |t| t[:en_el_pasado] }, omitidas: cal.omitidas.size,
                   ventana_dias: Planes::Materializar::VENTANA_DIAS }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan no encontrado' }, status: :not_found
  rescue Date::Error, ArgumentError
    render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
  end

  # POST /api/aplicacion_planes
  # Body: { plan_trabajo_id:, fecha_inicio:, objetivo_tipo: 'Lote'|'Sala', objetivo_id: }
  def create
    plan = @club.plan_trabajos.find(params[:plan_trabajo_id])

    unless plan.es_plantilla?
      return render json: { error: 'Solo se pueden aplicar plantillas' }, status: :unprocessable_entity
    end

    if plan.plan_tareas.empty?
      return render json: { error: 'La plantilla no tiene tareas' }, status: :unprocessable_entity
    end

    fecha_inicio  = Date.parse(params[:fecha_inicio].to_s)
    objetivo_tipo = params[:objetivo_tipo].presence   # 'Lote' | 'Sala' | nil
    objetivo_id   = params[:objetivo_id].presence&.to_i
    # El objetivo se busca DENTRO de la organización: antes se guardaba el id tal cual llegaba.
    objetivo = objetivo_de(objetivo_tipo, objetivo_id)

    # Las fechas las calcula `Planes::Calendario` y las tareas aparecen una semana antes de su día
    # (`Planes::Materializar`): aplicar ya no crea el ciclo entero de una vez.
    calendario      = Planes::Calendario.new(plan: plan, fecha_inicio: fecha_inicio, objetivo: objetivo)
    tareas_omitidas = (calendario.ocurrencias && calendario.omitidas.size)
    @aplicacion, _creadas = Planes::Aplicar.call(plan: plan, por: current_user, fecha_inicio: fecha_inicio, objetivo: objetivo)

    render json: serialize_full(@aplicacion.reload).merge(tareas_omitidas: tareas_omitidas), status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan no encontrado' }, status: :not_found
  rescue Date::Error, ArgumentError
    render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /api/aplicacion_planes/:id
  def destroy
    if @aplicacion.tareas.where(estado: 'completada').any?
      return render json: { error: 'No se puede eliminar: hay tareas completadas' }, status: :unprocessable_entity
    end
    @aplicacion.tareas.where(estado: %w[pendiente en_progreso]).update_all(
      estado: 'cancelada', aplicacion_plan_id: nil
    )
    @aplicacion.destroy
    head :no_content
  end

  # POST /api/aplicacion_planes/:id/cancelar
  def cancelar
    @aplicacion.tareas.where(estado: %w[pendiente en_progreso]).update_all(estado: 'cancelada')
    @aplicacion.update!(estado: 'cancelado')
    render json: serialize(@aplicacion)
  end

  private

  def set_club
    @club = current_user.club
  end

  def set_aplicacion
    @aplicacion = @club.aplicacion_planes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Aplicación no encontrada' }, status: :not_found
  end

  def authorize_admin_or_supervisor!
    unless current_user.admin? || current_user.supervisor? || current_user.super_admin?
      render json: { error: 'Sin permiso' }, status: :forbidden
    end
  end

  # El lote o la sala, buscado DENTRO de la organización.
  def objetivo_de(tipo, id)
    case tipo.presence
    when 'Lote' then @club.lotes.find(id)
    when 'Sala' then @club.salas.find(id)
    end
  end

  def serialize(a)
    {
      id:             a.id,
      plan_trabajo:   { id: a.plan_trabajo_id, titulo: a.plan_trabajo.titulo },
      aplicado_por:   { id: a.aplicado_por_id, nombre: a.aplicado_por.nombre_completo },
      objetivo_tipo:  a.objetivo_tipo,
      objetivo_id:    a.objetivo_id,
      objetivo_nombre: a.objetivo_nombre,
      fecha_inicio:   a.fecha_inicio,
      estado:         a.estado,
      tareas_creadas: a.tareas_creadas,
      porcentaje_completado: a.porcentaje_completado,
      created_at:     a.created_at,
    }
  end

  # Lo que todavía no apareció: las tareas se crean una semana antes de su día. Va en el detalle,
  # para que se vea el plan entero aunque las listas sólo muestren lo próximo.
  def proximas(a)
    return [] unless a.estado == 'activo'

    desde = Time.zone.today + Planes::Materializar::VENTANA_DIAS + 1
    Planes::Calendario.new(plan: a.plan_trabajo, fecha_inicio: a.fecha_inicio, objetivo: a.objetivo, corte: a.created_at)
                      .ocurrencias.select { |oc| oc.fecha >= desde }
                      .map { |oc| { titulo: oc.plan_tarea.titulo.presence || oc.plan_tarea.tipo.humanize,
                                    tipo: oc.plan_tarea.tipo, fecha_programada: oc.fecha,
                                    aparece_el: Planes::Materializar.aparece_el(oc.fecha),
                                    asignada_a: oc.asignada ? { id: oc.asignada.id, nombre: oc.asignada.nombre_completo } : nil } }
  end

  def serialize_full(a)
    data = serialize(a)
    data[:proximas]     = proximas(a)
    data[:ventana_dias] = Planes::Materializar::VENTANA_DIAS
    data[:tareas] = a.tareas.includes(:asignada_a, :sala, :lote).map do |t|
      {
        id:               t.id,
        titulo:           t.titulo,
        tipo:             t.tipo,
        estado:           t.estado,
        prioridad:        t.prioridad,
        fecha_programada: t.fecha_programada,
        asignada_a:       t.asignada_a ? { id: t.asignada_a.id, nombre: t.asignada_a.nombre_completo } : nil,
        sala:             t.sala ? { id: t.sala.id, nombre: t.sala.nombre } : nil,
        lote:             t.lote ? { id: t.lote.id, nombre: t.lote.codigo } : nil,
      }
    end
    data
  end
end
