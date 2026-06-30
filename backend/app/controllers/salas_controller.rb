# backend/app/controllers/salas_controller.rb
class SalasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_salas_role!
  before_action :set_sala, only: [:show, :update, :destroy, :cargar_lote, :cambiar_fase, :registrar_sala]

  # Las salas son solo de cultivo (vegetativo/floración). Post-cosecha el lote no usa
  # sala (se ve por estado en Cosecha/Manicura), así que ya no hay transiciones por kind.
  TRANSICIONES_KIND = {}.freeze

  # Salas de proceso (cosecha/curado): se autocrean para conservar la sede del
  # lote post-cosecha, pero NO son salas que el usuario gestione. No se listan en el ABM
  # (los lotes cosechados/en proceso se ven desde Cosecha / Manicura, no como salas).
  KINDS_PROCESO = Sala::KINDS_PROCESO

  def index
    salas = current_user.club.salas
                        .cultivo
                        .includes(:sede, :lotes, :created_by)
                        .order(:nombre)

    if current_user.cultivador?
      ids = current_user.salas_ids_asignadas
      if ids.any?
        salas = salas.where(id: ids)
      else
        salas = salas.where(kind: %w[vegetativo floracion])
      end
    elsif current_user.manicura?
      ids = current_user.salas_ids_asignadas
      if ids.any?
        salas = salas.where(id: ids)
      else
        salas = salas.where(kind: 'manicura')
      end
    elsif current_user.supervisor?
      salas = salas.where(sede_id: current_user.sedes_ids_asignadas)
    end

    render json: salas.map { |s| serialize_sala(s) }
  end

  def show
    render json: serialize_sala_detail(@sala)
  end

  def create
    unless current_user.admin? || current_user.supervisor?
      return render json: { error: 'Solo admins y supervisores pueden crear salas' }, status: :forbidden
    end

    sala = current_user.club.salas.build(sala_params)
    sala.created_by = current_user

    if sala.save
      render json: serialize_sala(sala), status: :created
    else
      render json: { errors: sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    kind_antes = @sala.kind
    if @sala.update(sala_params)
      cascade_kind_a_lotes(kind_antes) if kind_cambio_veg_flo?(kind_antes)
      render json: serialize_sala_detail(@sala.reload)
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @sala.soft_delete!
    head :no_content
  end

  # POST /salas/:id/cargar_lote
  def cargar_lote
    unless current_user.admin? || current_user.cultivador? || current_user.manicura?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    transicion = TRANSICIONES_KIND[@sala.kind]
    unless transicion
      return render json: { error: "Esta sala (#{@sala.kind}) no acepta carga de lotes" }, status: :unprocessable_entity
    end

    lote = current_user.club.lotes.find(params.require(:lote_id))

    unless lote.estado == transicion[:desde]
      return render json: {
        error: "El lote debe estar en '#{transicion[:label_desde]}' para ingresar a esta sala (estado actual: #{lote.estado})"
      }, status: :unprocessable_entity
    end

    lote.update!(sala_id: @sala.id, estado: transicion[:hacia])

    render json: {
      message: "Lote #{lote.codigo} cargado correctamente (#{transicion[:label_desde]} → #{transicion[:label_hacia]})",
      lote: { id: lote.id, codigo: lote.codigo, estado: lote.estado, sala_id: lote.sala_id }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  rescue => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # POST /salas/:id/registrar_sala
  # Crea un RegistroAmbiental en todos los lotes activos de la sala.
  def registrar_sala
    unless %w[admin supervisor cultivador].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    lotes_activos = @sala.lotes.where(estado: %w[vegetativo floracion])

    if lotes_activos.empty?
      return render json: { error: 'No hay lotes activos en esta sala' }, status: :unprocessable_entity
    end

    count = 0
    ActiveRecord::Base.transaction do
      lotes_activos.each do |lote|
        registro = lote.registros_ambientales.build(sala_registro_params)
        registro.user          = current_user
        registro.club          = current_user.club
        registro.registrado_en = Time.current
        registro.save!
        count += 1
      end
    end

    render json: { lotes_afectados: count }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /salas/:id/cambiar_fase
  # Cambia toda la sala de vegetativo ↔ floración. Afecta lotes y plantas activas.
  # Accesible a admin, supervisor y cultivador.
  def cambiar_fase
    unless %w[admin supervisor cultivador].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    unless %w[vegetativo floracion].include?(@sala.kind)
      return render json: { error: 'Solo las salas en vegetativo o floración pueden cambiar de fase' }, status: :unprocessable_entity
    end

    nueva_fase        = @sala.kind == 'vegetativo' ? 'floracion' : 'vegetativo'
    plant_state_orig  = @sala.kind   # 'vegetativo' | 'floracion'
    plant_state_dest  = nueva_fase

    lotes_a_cambiar = @sala.lotes.where(estado: @sala.kind)

    if lotes_a_cambiar.empty?
      return render json: {
        error: "No hay lotes en #{@sala.kind} en esta sala para cambiar de fase"
      }, status: :unprocessable_entity
    end

    lotes_count   = 0
    plantas_count = 0

    ActiveRecord::Base.transaction do
      lotes_a_cambiar.each do |lote|
        estado_anterior = lote.estado
        plantas = lote.plants.where(state: plant_state_orig)
        plantas_count += plantas.count
        plantas.update_all(state: plant_state_dest)

        lote.update!(estado: nueva_fase)

        lote.lote_eventos.create!(
          tipo:            'cambio_estado',
          estado_anterior: estado_anterior,
          estado_nuevo:    nueva_fase,
          descripcion:     "Cambio de fase grupal desde sala #{@sala.nombre}: #{estado_anterior} → #{nueva_fase}",
          user:            current_user,
          club:            current_user.club,
          registrado_en:   Time.current,
        )

        lotes_count += 1
      end

      @sala.update!(kind: nueva_fase)
    end

    render json: {
      sala:              serialize_sala_detail(@sala.reload),
      nueva_fase:        nueva_fase,
      lotes_afectados:   lotes_count,
      plantas_afectadas: plantas_count,
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_sala
    scope = current_user.club.salas
    if current_user.cultivador?
      ids = current_user.salas_ids_asignadas
      if ids.any?
        scope = scope.where(id: ids)
      else
        scope = scope.where(kind: %w[vegetativo floracion])
      end
    elsif current_user.manicura?
      ids = current_user.salas_ids_asignadas
      if ids.any?
        scope = scope.where(id: ids)
      else
        scope = scope.where(kind: 'manicura')
      end
    elsif current_user.supervisor?
      scope = scope.where(sede_id: current_user.sedes_ids_asignadas)
    end
    @sala = scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def require_salas_role!
    blocked = %w[auditor abogado paciente]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  KINDS_VEG_FLO = %w[vegetativo floracion].freeze

  def kind_cambio_veg_flo?(kind_antes)
    KINDS_VEG_FLO.include?(kind_antes) && KINDS_VEG_FLO.include?(@sala.kind) && kind_antes != @sala.kind
  end

  def cascade_kind_a_lotes(kind_antes)
    nueva_fase = @sala.kind
    lotes = @sala.lotes.where(estado: kind_antes)
    return if lotes.empty?

    ActiveRecord::Base.transaction do
      lotes.each do |lote|
        lote.plants.where(state: kind_antes).update_all(state: nueva_fase)
        lote.update!(estado: nueva_fase)
        lote.lote_eventos.create!(
          tipo:            'cambio_estado',
          estado_anterior: kind_antes,
          estado_nuevo:    nueva_fase,
          descripcion:     "Cambio de fase por edición de sala #{@sala.nombre}: #{kind_antes} → #{nueva_fase}",
          user:            current_user,
          club:            current_user.club,
          registrado_en:   Time.current,
        )
      end
    end
  end

  def sala_registro_params
    params.require(:registro_ambiental).permit(
      :temperatura, :humedad, :co2, :ph, :ec,
      :temperatura_sustrato, :ph_runoff, :ec_runoff, :ppfd,
      :horas_luz, :espectro_luz, :fase_nutricional,
      :ml_nutrientes_litro, :notas_nutricion,
      :fertilizacion, :notas_fertilizacion,
      :estado_general, :plagas_observadas,
      :observaciones, :fuente,
      tareas_realizadas: []
    )
  end

  def sala_params
    params.require(:sala).permit(
      :nombre, :state, :kind, :notes, :pots_count, :sede_id,
      :camera_stream_url, :camera_snapshot_url, :responsable_id
    )
  end

  def serialize_sala(s)
    {
      id:                   s.id,
      club_id:              s.club_id,
      nombre:               s.nombre,
      tipo:                 s.tipo,
      state:                s.state,
      kind:                 s.kind,
      notes:                s.notes,
      pots_count:           s.pots_count,   # posiciones físicas para el Layout (no es capacidad)
      plantas_totales:      s.plantas_totales,
      lotes_count:          s.lotes.count,
      sede_id:              s.sede_id,
      sede: s.sede ? { id: s.sede.id, nombre: s.sede.nombre, tipo: s.sede.tipo } : nil,
      created_at:           s.created_at,
      created_by_name:      s.created_by_name,
      lotes_activos:        s.lotes.where(estado: ['vegetativo','floracion']).count,
      lotes_activos_count:  s.lotes.where.not(estado: ['finalizado','curado']).count,
      updated_at:           s.updated_at,
      responsable_id:      s.responsable_id,
      responsable_nombre:  s.responsable&.nombre_completo,
      cultivadores:        s.cultivadores.map { |c| { id: c.id, nombre: c.nombre_completo } },
      camera_stream_url:   s.camera_stream_url,
      camera_snapshot_url: s.camera_snapshot_url,
    }
  end

  def serialize_sala_detail(s)
    lotes_all = s.lotes.includes(:genetica).order(start_date: :desc, created_at: :desc)
    lote_ids  = lotes_all.map(&:id)

    # Conteo VIVO de plantas por lote (excluye descartadas; el default scope ya excluye
    # las eliminadas). Es la verdad, no el campo plants_count denormalizado que puede driftear.
    plantas_vivas_por_lote = Plant.where(lote_id: lote_ids).where.not(state: 'descartada').group(:lote_id).count
    plantas_vivas = ->(id) { plantas_vivas_por_lote[id] || 0 }

    fecha_cosecha_por_lote =
      lote_ids.any? ?
        Plant.where(lote_id: lote_ids)
             .where.not(fecha_cosecha: nil)
             .group(:lote_id)
             .maximum(:fecha_cosecha)
      : {}

    lotes_historial = lotes_all.map do |l|
      fecha_cosecha = fecha_cosecha_por_lote[l.id]
      duracion = l.start_date && fecha_cosecha ? (fecha_cosecha.to_date - l.start_date).to_i : nil
      {
        id:                 l.id,
        codigo:             l.codigo,
        estado:             l.estado,
        start_date:         l.start_date,
        plants_count:       plantas_vivas.(l.id),
        genetica_nombre:    l.genetica&.nombre,
        rendimiento_real_g: l.rendimiento_real_g&.to_f,
        fecha_cosecha:      fecha_cosecha,
        duracion_dias:      duracion,
      }
    end

    vals_rend      = lotes_historial.filter_map { |l| l[:rendimiento_real_g] }
    ciclos_fin     = lotes_historial.count { |l| l[:estado] == 'finalizado' }
    duraciones     = lotes_historial.filter_map { |l| l[:duracion_dias] }

    historial_kpis = {
      total_ciclos:           lotes_historial.size,
      ciclos_finalizados:     ciclos_fin,
      duracion_promedio_dias: duraciones.any? ? (duraciones.sum.to_f / duraciones.size).round(0).to_i : nil,
      rendimiento_promedio_g: vals_rend.any? ? (vals_rend.sum / vals_rend.size).round(1) : nil,
    }

    serialize_sala(s).merge(
      lotes: lotes_all.map { |l|
        { id: l.id, codigo: l.codigo, estado: l.estado, plants_count: plantas_vivas.(l.id) }
      },
      lotes_historial:,
      historial_kpis:,
    )
  end
end
