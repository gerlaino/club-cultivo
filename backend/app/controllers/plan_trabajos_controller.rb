class PlanTrabajosController < ApplicationController
  include DescargaProfesional
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :authorize_admin_or_supervisor!
  before_action :set_club
  before_action :set_plan, only: [:show, :update, :destroy, :publicar, :archivar, :export_csv]


  # GET /api/plan_trabajos
  def index
    planes = @club.plan_trabajos
      .includes(:creado_por, :sede, :plan_tareas)
      .order(created_at: :desc)

    planes = planes.where(estado:       params[:estado])      if params[:estado].present?
    planes = planes.where(es_plantilla: params[:plantilla] == 'true') if params[:plantilla].present?

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
      return render json: { error: 'No se puede eliminar un plan publicado. Archivalo primero.' }, status: :unprocessable_entity
    end

    tareas_eliminadas = @plan.tareas_generadas
                             .where(estado: %w[pendiente en_progreso])
                             .destroy_all
                             .size

    # Nullify plan_tarea_id en las tareas restantes (completadas/canceladas)
    # antes de que dependent: :destroy borre los plan_tareas y viole la FK
    @plan.tareas_generadas.update_all(plan_tarea_id: nil)

    @plan.destroy
    render json: { tareas_eliminadas: tareas_eliminadas }
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
      @plan.update!(estado: :publicado, publicado_en: Time.zone.now)
      # Una PLANTILLA no crea tareas al publicarse: no tiene fechas, se aplica a un lote o a una
      # sala. Antes las creaba igual, con la fecha de inicio del plan —que una plantilla no tiene—,
      # y quedaban tareas pendientes SIN FECHA que nadie sabía de dónde salían.
      # Un plan con fechas se aplica a toda la organización con la cuenta única
      # (`Planes::Calendario`): sus tareas aparecen una semana antes de su día.
      unless @plan.es_plantilla?
        _aplicacion, creadas = Planes::Aplicar.call(plan: @plan, por: current_user, fecha_inicio: @plan.fecha_inicio)
        tareas_creadas = creadas.size
      end
    end

    plan_data = serialize_plan(@plan.reload)
    plan_data[:plan_tareas] = @plan.plan_tareas.includes(:responsable, :sala).map { |pt| serialize_plan_tarea(pt) }
    render json: plan_data.merge(tareas_creadas: tareas_creadas)
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/plan_trabajos/:id/archivar
  def archivar
    @plan.update!(estado: :archivado)
    render json: serialize_plan(@plan)
  end

  # GET /api/plan_trabajos/:id/export_csv?modo=plantilla|calendario&fecha_inicio=YYYY-MM-DD&formato=pdf|xlsx
  #
  # El plan como se lee: semana por semana, qué toca y qué hay que hacer, en PDF o Excel
  # (`DescargaProfesional`). Era un CSV con `dia,tipo,titulo,rol_sugerido` y la descripción partida
  # en celdas (Germán, 9-oct-2026: «esta horrible esto, no se entiende»).
  def export_csv
    calendario = params[:modo] == 'calendario'
    inicio     = Date.parse(params[:fecha_inicio].to_s) if calendario
    tareas     = @plan.plan_tareas.order(:dia_relativo, :id).to_a
    personal   = @club.personal?
    prioridad  = { 'baja' => 'Baja', 'normal' => 'Normal', 'alta' => 'Alta', 'urgente' => 'Urgente' }
    cuando = ->(pt) {
      d = pt.dia_relativo.to_i
      calendario ? (inicio + d.days) : "Semana #{d / 7 + 1} · día #{d % 7 + 1}"
    }
    que = ->(pt) { [Tarea::TIPO_LABELS[pt.tipo] || pt.tipo.to_s.humanize, (pt.titulo if pt.titulo.present? && pt.titulo != Tarea::TIPO_LABELS[pt.tipo])].compact.join(' — ') }
    headers  = [calendario ? 'Fecha' : 'Cuándo', 'Tarea', 'Qué hay que hacer', 'Prioridad']
    formatos = [calendario ? :fecha : :texto, :texto, :texto, :texto]
    unless personal
      headers << 'Quién'
      formatos << :texto
    end
    responder_descarga(
      titulo: "Plan de trabajo — #{@plan.titulo}", nombre: "plan-#{@plan.titulo.parameterize}",
      periodo: (calendario ? "Desde el #{inicio.strftime('%d/%m/%Y')}" : 'Semanas contadas desde el inicio del lote'),
      kpis: [{ label: 'Tareas', valor: tareas.size },
             { label: 'Semanas', valor: tareas.map { |pt| pt.dia_relativo.to_i / 7 + 1 }.max || 0 }],
      headers: headers, formatos: formatos, apaisado: false,
      rows: tareas.map { |pt|
        fila = [cuando.(pt), que.(pt), pt.descripcion.to_s.strip.gsub(/\n?---\n?/, "\n").presence, prioridad[pt.prioridad] || pt.prioridad]
        fila << (pt.responsable&.nombre_completo || pt.rol_sugerido.to_s.split(',').map { |r| r.strip.humanize }.join(', ').presence) unless personal
        fila
      },
    )
  rescue Date::Error, ArgumentError
    render json: { error: 'Fecha inválida' }, status: :unprocessable_entity
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
      :sede_id, :estado, :repetir_automaticamente, :notas, :es_plantilla
    )
  end

  def plan_tarea_params
    params.require(:plan_tarea).permit(
      :titulo, :tipo, :responsable_id, :prioridad, :sala_id,
      :descripcion, :dias_semana, :hora, :es_recurrente,
      :fecha_especifica, :origen_ia, :confirmada, :dia_relativo, :rol_sugerido
    )
  end

  def plan_tarea_permit(raw)
    raw.permit(
      :titulo, :tipo, :responsable_id, :prioridad, :sala_id,
      :descripcion, :dias_semana, :hora, :es_recurrente,
      :fecha_especifica, :origen_ia, :confirmada, :dia_relativo, :rol_sugerido
    )
  rescue
    raw.slice(*%w[titulo tipo responsable_id prioridad sala_id descripcion dias_semana hora es_recurrente fecha_especifica origen_ia confirmada dia_relativo rol_sugerido])
  end

  def propagar_cambios(pt, scope)
    tareas = case scope
             when 'todas'       then @club.tareas.where(plan_tarea_id: pt.id)
             when 'siguientes'  then @club.tareas.where(plan_tarea_id: pt.id)
                                              .where('fecha_programada >= ?', Time.zone.today)
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
      es_plantilla:            plan.es_plantilla,
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
      dia_relativo:     pt.dia_relativo,
      rol_sugerido:     pt.rol_sugerido,
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
