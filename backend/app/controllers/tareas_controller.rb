class TareasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_club
  before_action :set_tarea, only: [:show, :update, :destroy, :completar, :iniciar, :cancelar]
  before_action :authorize_create!, only: [:create]
  before_action :authorize_manage!, only: [:update, :destroy]

  # GET /api/v1/tareas
  # Soporta filtros: estado, asignada_a_id, sala_id, lote_id, tipo, fecha_desde, fecha_hasta, scope
  def index
    tareas = @club.tareas.includes(:asignada_a, :creada_por, :sala, :lote, :plant)

    # scope especial para dashboard del cultivador
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

    tareas = tareas.por_prioridad.order(fecha_programada: :asc, created_at: :desc)

    render json: tareas.map { |t| serialize_tarea(t) }
  end

  # GET /api/v1/tareas/dashboard
  # Resumen para el dashboard del cultivador
  def dashboard
    base = @club.tareas.asignadas_a(current_user.id)

    render json: {
      hoy: base.de_hoy.map { |t| serialize_tarea(t) },
      vencidas: base.vencidas.por_prioridad.limit(5).map { |t| serialize_tarea(t) },
      proximas: base.proximas.where.not(fecha_programada: Date.today)
                    .por_prioridad.limit(10).map { |t| serialize_tarea(t) },
      stats: {
        pendientes: base.pendientes.count,
        en_progreso: base.en_progreso.count,
        completadas_hoy: base.completadas.where(fecha_completada: Date.today.all_day).count,
        vencidas: base.vencidas.count
      }
    }
  end

  # GET /api/v1/tareas/kanban
  # Devuelve tareas agrupadas por estado para el kanban
  def kanban
    tareas = @club.tareas.includes(:asignada_a, :creada_por, :sala, :lote)

    # Cultivadores solo ven las suyas
    if current_user.cultivador?
      tareas = tareas.asignadas_a(current_user.id)
    end

    tareas = tareas.where(asignada_a_id: params[:asignada_a_id]) if params[:asignada_a_id].present?
    tareas = tareas.where(sala_id: params[:sala_id])             if params[:sala_id].present?
    tareas = tareas.where(lote_id: params[:lote_id])             if params[:lote_id].present?

    # Solo mostrar no-canceladas en kanban
    tareas = tareas.where(estado: %w[pendiente en_progreso completada])
                   .por_prioridad.order(updated_at: :desc)

    render json: {
      pendiente:   tareas.select { |t| t.estado == 'pendiente' }.map { |t| serialize_tarea(t) },
      en_progreso: tareas.select { |t| t.estado == 'en_progreso' }.map { |t| serialize_tarea(t) },
      completada:  tareas.select { |t| t.estado == 'completada' }.first(20).map { |t| serialize_tarea(t) }
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

    if tarea.save
      render json: serialize_tarea(tarea), status: :created
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

    horas = params[:horas_reales]&.to_f
    notas = params[:notas_completado]

    @tarea.completar!(horas_reales: horas, notas: notas)

    render json: {
      tarea: serialize_tarea(@tarea),
      tiene_horas_para_lote: @tarea.tiene_horas_para_lote?
    }
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
    if @tarea.completada?
      return render json: { error: 'No se pueden eliminar tareas completadas' }, status: :unprocessable_entity
    end
    @tarea.destroy
    head :no_content
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
      :notas_completado, :horas_aplicadas_al_lote
    )
  end

  def authorize_create!
    unless current_user.admin? || current_user.agricultor? || current_user.cultivador?
      render json: { error: 'Sin permiso para crear tareas' }, status: :forbidden
    end
  end

  def authorize_manage!
    unless current_user.admin? || current_user.agricultor? ||
           (current_user.cultivador? && @tarea.asignada_a_id == current_user.id)
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
      sala: t.sala ? { id: t.sala.id, nombre: t.sala.nombre } : nil,
      lote: t.lote ? { id: t.lote.id, codigo: t.lote.codigo } : nil,
      plant: t.plant ? { id: t.plant.id, codigo_qr: t.plant.codigo_qr, nombre: t.plant.nombre } : nil,
      created_at: t.created_at,
      updated_at: t.updated_at
    }
  end
end