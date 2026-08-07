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

    fecha_inicio = Date.parse(params[:fecha_inicio].to_s)
    objetivo_tipo = params[:objetivo_tipo].presence   # 'Lote' | 'Sala' | nil
    objetivo_id   = params[:objetivo_id].presence&.to_i

    tareas_creadas = 0

    ActiveRecord::Base.transaction do
      @aplicacion = @club.aplicacion_planes.create!(
        plan_trabajo:  plan,
        aplicado_por:  current_user,
        fecha_inicio:  fecha_inicio,
        objetivo_tipo: objetivo_tipo,
        objetivo_id:   objetivo_id,
        estado:        'activo',
        tareas_creadas: 0
      )

      # Pre-cargar usuarios del club por rol para no hacer N queries
      usuarios_por_rol = @club.users.group_by(&:role)

      plan.plan_tareas.includes(:responsable, :sala).each do |pt|
        dia   = pt.dia_relativo || 0
        fecha = fecha_inicio + dia.days

        sala_id = pt.sala_id
        lote_id = nil

        if objetivo_tipo == 'Sala' && objetivo_id
          sala_id ||= objetivo_id
        end

        if objetivo_tipo == 'Lote' && objetivo_id
          lote_id = objetivo_id
          lote    = Lote.find_by(id: objetivo_id)
          sala_id ||= lote&.sala_id
        end

        # Resolver a quién asignar: si hay roles sugeridos → un task por usuario del rol
        asignados = if pt.rol_sugerido.present?
          roles = pt.rol_sugerido.split(',').map(&:strip).reject(&:blank?)
          roles.flat_map { |rol| usuarios_por_rol[rol] || [] }.uniq
        else
          []
        end

        # Si hay responsable_id explícito o no se encontraron usuarios del rol → una tarea sin asignar (o al responsable)
        asignados = [pt.responsable] if asignados.empty?

        asignados.each do |usuario|
          @club.tareas.create!(
            titulo:             pt.titulo.presence || pt.tipo,
            descripcion:        pt.descripcion,
            tipo:               pt.tipo,
            estado:             'pendiente',
            prioridad:          pt.prioridad,
            asignada_a_id:      usuario&.id,
            sala_id:            sala_id,
            lote_id:            lote_id,
            fecha_programada:   fecha,
            creada_por:         current_user,
            origen_plan_id:     plan.id,
            plan_tarea_id:      pt.id,
            aplicacion_plan_id: @aplicacion.id
          )
          tareas_creadas += 1
        end
      end

      @aplicacion.update!(tareas_creadas: tareas_creadas)
    end

    render json: serialize_full(@aplicacion.reload), status: :created
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

  def serialize_full(a)
    data = serialize(a)
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
