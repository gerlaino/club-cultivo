class PlanTrabajosController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin_or_supervisor!
  before_action :set_club
  before_action :set_plan, only: [:show, :update, :destroy, :publicar, :archivar]

  DIAS_A_WDAY = { 'lun' => 1, 'mar' => 2, 'mie' => 3, 'jue' => 4, 'vie' => 5, 'sab' => 6, 'dom' => 0 }.freeze

  # GET /api/plan_trabajos
  def index
    planes = @club.plan_trabajos
      .includes(:creado_por, :sede, :plan_tareas)
      .order(created_at: :desc)

    planes = planes.where(estado: params[:estado]) if params[:estado].present?

    render json: planes.map { |p| serialize_plan(p) }
  end

  # GET /api/plan_trabajos/activo
  def activo
    plan = @club.plan_trabajos.vigentes.order(fecha_inicio: :desc).first
    return render json: nil unless plan

    plan_data = serialize_plan(plan)
    plan_data[:plan_tareas] = plan.plan_tareas.includes(:responsable, :sala).map { |pt| serialize_plan_tarea(pt) }
    render json: plan_data
  end

  # GET /api/plan_trabajos/:id
  def show
    data = serialize_plan(@plan)
    data[:plan_tareas] = @plan.plan_tareas.includes(:responsable, :sala, :tarea_generada).map { |pt| serialize_plan_tarea(pt) }
    render json: data
  end

  # POST /api/plan_trabajos
  def create
    @plan = @club.plan_trabajos.build(plan_params)
    @plan.creado_por = current_user

    if @plan.save
      if params[:plan_tareas].is_a?(Array)
        params[:plan_tareas].each do |pt_data|
          @plan.plan_tareas.create(plan_tarea_permit(pt_data))
        end
      end
      render json: serialize_plan(@plan), status: :created
    else
      render json: { errors: @plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/plan_trabajos/:id
  def update
    if @plan.publicado?
      return render json: { error: 'No se puede editar un plan publicado' }, status: :unprocessable_entity
    end
    if @plan.update(plan_params)
      render json: serialize_plan(@plan)
    else
      render json: { errors: @plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/plan_trabajos/:id
  def destroy
    if @plan.publicado?
      return render json: { error: 'No se puede eliminar un plan publicado' }, status: :unprocessable_entity
    end
    @plan.destroy
    head :no_content
  end

  # POST /api/plan_trabajos/:id/publicar
  def publicar
    if @plan.publicado?
      return render json: { error: 'El plan ya está publicado' }, status: :unprocessable_entity
    end
    if @plan.plan_tareas.empty?
      return render json: { error: 'El plan no tiene tareas' }, status: :unprocessable_entity
    end

    tareas_creadas = 0

    ActiveRecord::Base.transaction do
      @plan.plan_tareas.includes(:responsable, :sala).each do |pt|
        if pt.es_recurrente?
          fechas = calcular_fechas(pt)
          primera = nil
          fechas.each_with_index do |fecha, idx|
            tarea = crear_tarea!(pt, fecha)
            primera = tarea if idx.zero?
            tareas_creadas += 1
          end
          pt.update!(tarea_generada_id: primera&.id)
        else
          fecha = pt.fecha_especifica || @plan.fecha_inicio
          tarea = crear_tarea!(pt, fecha)
          pt.update!(tarea_generada_id: tarea.id)
          tareas_creadas += 1
        end
      end

      @plan.update!(estado: :publicado, publicado_en: Time.zone.now)
    end

    render json: { ok: true, tareas_creadas: tareas_creadas }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/plan_trabajos/:id/archivar
  def archivar
    @plan.update!(estado: :archivado)
    render json: serialize_plan(@plan)
  end

  # POST /api/plan_trabajos/interpretar_archivo
  def interpretar_archivo
    archivo = params[:archivo]
    return render json: { error: "No se recibió archivo" }, status: :unprocessable_entity unless archivo

    resultado = PlanTrabajoIaService.new(archivo, @club).interpretar
    render json: resultado
  rescue => e
    Rails.logger.error "interpretar_archivo error: #{e.message}"
    render json: { error: "Error al procesar el archivo", tareas: [], ambiguas: [], total: 0, recurrentes: 0 }, status: :unprocessable_entity
  end

  # ── Plan Tareas (nested) ──────────────────────────────────────

  # GET /api/plan_trabajos/:id/plan_tareas
  def plan_tareas_index
    set_plan
    render json: @plan.plan_tareas.includes(:responsable, :sala).map { |pt| serialize_plan_tarea(pt) }
  end

  # POST /api/plan_trabajos/:id/plan_tareas
  def plan_tareas_create
    set_plan
    pt = @plan.plan_tareas.build(plan_tarea_params)
    if pt.save
      render json: serialize_plan_tarea(pt), status: :created
    else
      render json: { errors: pt.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/plan_trabajos/:id/plan_tareas/:tid
  def plan_tareas_update
    set_plan
    pt = @plan.plan_tareas.find(params[:tid])
    scope = params[:scope] || 'esta'

    if pt.update(plan_tarea_params)
      propagar_cambios(pt, scope) if @plan.publicado?
      render json: serialize_plan_tarea(pt)
    else
      render json: { errors: pt.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/plan_trabajos/:id/plan_tareas/:tid
  def plan_tareas_destroy
    set_plan
    pt = @plan.plan_tareas.find(params[:tid])
    pt.destroy
    head :no_content
  end

  private

  def set_club
    @club = current_user.club
  end

  def set_plan
    @plan = @club.plan_trabajos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Plan no encontrado' }, status: :not_found
  end

  def authorize_admin_or_supervisor!
    unless current_user.admin? || current_user.supervisor? || current_user.super_admin?
      render json: { error: 'Sin permiso para acceder a planes de trabajo' }, status: :forbidden
    end
  end

  def plan_params
    params.require(:plan_trabajo).permit(
      :titulo, :periodo_tipo, :fecha_inicio, :fecha_fin,
      :sede_id, :estado, :repetir_automaticamente, :notas
    )
  end

  def plan_tarea_params
    params.require(:plan_tarea).permit(
      :titulo, :tipo, :responsable_id, :prioridad, :sala_id,
      :descripcion, :dias_semana, :hora, :es_recurrente,
      :fecha_especifica, :origen_ia, :confirmada
    )
  end

  def plan_tarea_permit(raw)
    raw.permit(
      :titulo, :tipo, :responsable_id, :prioridad, :sala_id,
      :descripcion, :dias_semana, :hora, :es_recurrente,
      :fecha_especifica, :origen_ia, :confirmada
    )
  rescue
    raw.slice(*%w[titulo tipo responsable_id prioridad sala_id descripcion dias_semana hora es_recurrente fecha_especifica origen_ia confirmada])
  end

  def calcular_fechas(plan_tarea)
    return [] if plan_tarea.dias_semana.blank?

    wdays_objetivo = plan_tarea.dias_array.filter_map { |d| DIAS_A_WDAY[d] }
    fechas = []
    fecha  = @plan.fecha_inicio
    while fecha <= @plan.fecha_fin
      fechas << fecha if wdays_objetivo.include?(fecha.wday)
      fecha += 1.day
    end
    fechas
  end

  def crear_tarea!(plan_tarea, fecha)
    @club.tareas.create!(
      titulo:          plan_tarea.titulo.presence || plan_tarea.tipo,
      descripcion:     plan_tarea.descripcion,
      tipo:            plan_tarea.tipo,
      estado:          'pendiente',
      prioridad:       plan_tarea.prioridad,
      asignada_a_id:   plan_tarea.responsable_id,
      sala_id:         plan_tarea.sala_id,
      fecha_programada: fecha,
      recurrente:      plan_tarea.es_recurrente,
      creada_por:      current_user,
      origen_plan_id:  @plan.id,
      plan_tarea_id:   plan_tarea.id
    )
  end

  def propagar_cambios(pt, scope)
    tareas = case scope
             when 'todas'       then @club.tareas.where(plan_tarea_id: pt.id)
             when 'siguientes'  then @club.tareas.where(plan_tarea_id: pt.id)
                                              .where('fecha_programada >= ?', Date.today)
             else return
             end

    tareas.update_all(
      asignada_a_id: pt.responsable_id,
      sala_id:       pt.sala_id,
      descripcion:   pt.descripcion,
      prioridad:     pt.prioridad
    )
  end

  def serialize_plan(plan)
    {
      id:                      plan.id,
      titulo:                  plan.titulo,
      periodo_tipo:            plan.periodo_tipo,
      fecha_inicio:            plan.fecha_inicio,
      fecha_fin:               plan.fecha_fin,
      estado:                  plan.estado,
      repetir_automaticamente: plan.repetir_automaticamente,
      notas:                   plan.notas,
      publicado_en:            plan.publicado_en,
      duracion_dias:           plan.duracion_dias,
      total_plan_tareas:       plan.total_plan_tareas,
      porcentaje_completado:   plan.porcentaje_completado,
      sede:                    plan.sede ? { id: plan.sede.id, nombre: plan.sede.nombre } : nil,
      creado_por:              { id: plan.creado_por.id, nombre: plan.creado_por.nombre_completo },
      created_at:              plan.created_at,
    }
  end

  def serialize_plan_tarea(pt)
    {
      id:               pt.id,
      plan_trabajo_id:  pt.plan_trabajo_id,
      titulo:           pt.titulo,
      titulo_display:   pt.titulo_display,
      tipo:             pt.tipo,
      prioridad:        pt.prioridad,
      descripcion:      pt.descripcion,
      dias_semana:      pt.dias_semana,
      dias_array:       pt.dias_array,
      hora:             pt.hora,
      es_recurrente:    pt.es_recurrente,
      recurrencia_id:   pt.recurrencia_id,
      fecha_especifica: pt.fecha_especifica,
      origen_ia:        pt.origen_ia,
      confirmada:       pt.confirmada,
      tarea_generada_id: pt.tarea_generada_id,
      responsable:      pt.responsable ? { id: pt.responsable.id, nombre: pt.responsable.nombre_completo } : nil,
      sala:             pt.sala        ? { id: pt.sala.id,        nombre: pt.sala.nombre               } : nil,
    }
  end
end
