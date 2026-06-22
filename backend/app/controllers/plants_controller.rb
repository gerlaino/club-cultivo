class PlantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plant, only: [:show, :update, :destroy, :add_foto, :remove_foto, :registrar_peso]

  # GET /plants
  def index
    plants = Plant.joins(:lote).where(lotes: { club_id: current_user.club_id })

    if params[:lote_id].present?
      # Con lote_id explícito la unidad de acceso es el lote (ya scoped al club).
      # No aplicamos el filtro de sala asignada: el cultivador puede ver las plantas
      # del lote al que navega, independientemente de si está en sala_cultivadores.
      return render json: [] unless current_user.club.lotes.exists?(id: params[:lote_id])
      plants = plants.where(lote_id: params[:lote_id])
    else
      if current_user.cultivador?
        salas_ids = current_user.salas_ids_asignadas
        plants = plants.where(lotes: { sala_id: salas_ids })
      elsif current_user.supervisor?
        salas_ids = current_user.salas_ids_en_sedes_asignadas
        plants = plants.where(lotes: { sala_id: salas_ids })
      end
    end
    plants = plants.where(state: params[:state])                if params[:state].present?
    plants = plants.where(lotes: { estado: params[:lote_estado] }) if params[:lote_estado].present?
    plants = plants.includes(lote: [:genetica, { sala: :sede }]).order(created_at: :desc)
    render json: plants.map { |p| serialize_plant(p) }
  end

  # GET /plants/:id
  def show
    render json: serialize_plant_detail(@plant)
  end

  # POST /plants
  def create
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_planta?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('plantas', info[:limites][:plantas]), status: :payment_required
    end

    lote = current_user.club.lotes.find(params[:plant][:lote_id])
    sala = lote.sala

    if sala&.tiene_limite_capacidad? && sala.capacidad_disponible == 0
      return render json: {
        errors: ["La sala '#{sala.nombre}' está al límite de su capacidad (#{sala.capacidad_maxima} plantas)"]
      }, status: :unprocessable_entity
    end

    # Nombre autogenerado — el usuario no lo ingresa
    count  = lote.plants.count + 1
    nombre = "#{lote.codigo}-P#{count.to_s.rjust(3, '0')}"

    plant = lote.plants.build(plant_params.except(:nombre, :genetica_id))
    plant.nombre = nombre

    if plant.save
      attach_foto(plant) if params[:foto].present?
      lote.increment!(:plants_count)
      lote.lote_eventos.create!(
        tipo:          'nota',
        descripcion:   "Planta #{plant.nombre} añadida al lote",
        user:          current_user,
        club:          current_user.club,
        registrado_en: Time.current,
      )
      render json: serialize_plant(plant), status: :created
    else
      render json: { errors: plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /plants/:id
  def update
    old_state = @plant.state

    permitted = plant_params.except(:nombre, :genetica_id) # nombre y genetica_id nunca se editan en la planta
    if @plant.update(permitted)
      attach_foto(@plant) if params[:foto].present?
      if plant_params[:state].present? && @plant.state != old_state
        @plant.activities.create!(
          user:          current_user,
          activity_type: 'state_change',
          description:   "Estado cambiado de #{old_state} a #{@plant.state}",
          occurred_at:   Time.current
        )
        if @plant.state == 'descartada' && old_state != 'descartada'
          @plant.lote.lote_eventos.create!(
            tipo:          'nota',
            descripcion:   "Planta #{@plant.nombre} descartada (estaba en #{old_state})",
            user:          current_user,
            club:          current_user.club,
            registrado_en: Time.current,
          )
          # Una planta descartada deja de contar como planta viva del lote.
          @plant.lote.decrement!(:plants_count) if @plant.lote.plants_count.to_i > 0
        elsif old_state == 'descartada' && @plant.state != 'descartada'
          @plant.lote.increment!(:plants_count) # se revierte el descarte
        end
      end
      render json: serialize_plant_detail(@plant)
    else
      render json: { errors: @plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /plants/:id
  def destroy
    lote = @plant.lote
    @plant.soft_delete!
    lote.decrement!(:plants_count) if lote.plants_count.to_i > 0
    head :no_content
  end

  # POST /plants/:id/add_foto
  def add_foto
    unless params[:foto].present?
      return render json: { error: 'No se recibió ninguna foto' }, status: :unprocessable_entity
    end
    begin
      @plant.fotos.attach(params[:foto])
    rescue RedisClient::CannotConnectError, Redis::CannotConnectError => e
      Rails.logger.warn "[add_foto] Redis no disponible, análisis de imagen omitido: #{e.message}"
    end
    blob = @plant.fotos.blobs.order(created_at: :desc).first
    return render json: { error: 'Error al guardar la foto' }, status: :unprocessable_entity unless blob

    if params[:descripcion].present?
      blob.update!(metadata: blob.metadata.merge('descripcion' => params[:descripcion].to_s.strip))
    end

    render json: serialize_blob(blob), status: :created
  end

  # POST /plants/:id/registrar_peso
  def registrar_peso
    peso_seco   = params[:peso_seco_g].to_f
    peso_humedo = params[:peso_humedo_g].present? ? params[:peso_humedo_g].to_f : nil
    return render json: { error: 'El peso debe ser mayor a 0' }, status: :unprocessable_entity if peso_seco <= 0

    lote = @plant.lote
    unless %w[en_manicura secado].include?(lote.estado)
      return render json: { error: 'El lote no está en una fase de manicura activa' }, status: :unprocessable_entity
    end

    authorized = current_user.admin? || current_user.supervisor? ||
                 (current_user.manicura? && lote.manicurador_id == current_user.id) ||
                 (current_user.manicura? && lote.manicurador_id.nil?)
    return render json: { error: 'No estás asignado a este lote' }, status: :forbidden unless authorized

    pesaje_manicura_id = params[:pesaje_manicura_id]

    ActiveRecord::Base.transaction do
      plant_attrs = { peso_seco: peso_seco }
      plant_attrs[:peso_humedo] = peso_humedo if peso_humedo&.positive?
      @plant.update!(plant_attrs)

      # Si el lote venía de 'secado' (camino viejo, sin manicura asignada), entra a
      # manicura activa al primer pesaje por QR. Mismo criterio que la carga por lote.
      if lote.estado == 'secado'
        lote.update!(estado: 'en_manicura', manicurador_id: lote.manicurador_id || current_user.id)
        lote.lote_eventos.create!(
          tipo: 'cambio_estado', estado_anterior: 'secado', estado_nuevo: 'en_manicura',
          descripcion: 'Inicio de manicura (pesaje por QR desde secado)',
          user: current_user, club: lote.club, registrado_en: Time.current,
        )
      end

      # Resolvemos la jornada (PesajeManicura): por id explícito, o el borrador abierto del
      # manicura para este lote. Si no hay ninguno, se crea. Flujo único: el peso siempre
      # alimenta un PesajeManicura.
      pesaje = if pesaje_manicura_id.present?
        lote.pesajes_manicura.where(estado: 'borrador', manicurador_id: current_user.id).find(pesaje_manicura_id)
      else
        lote.pesajes_manicura.where(estado: 'borrador', manicurador_id: current_user.id).order(created_at: :desc).first ||
          lote.pesajes_manicura.create!(manicurador: current_user, club: lote.club, fecha_pesaje: Date.current)
      end

      pp = pesaje.pesadas_plantas.find_or_initialize_by(plant_id: @plant.id)
      pp.pesaje_manicura = pesaje
      pp.pesada          = nil
      pp.peso_seco_g     = peso_seco
      pp.peso_humedo_g   = peso_humedo if peso_humedo&.positive?
      pp.save!

      total_peso = pesaje.pesadas_plantas.sum(:peso_seco_g)
      count      = pesaje.pesadas_plantas.count

      render json: {
        planta:    { id: @plant.id, nombre: @plant.nombre, codigo_qr: @plant.codigo_qr,
                     peso_seco: @plant.peso_seco.to_f, peso_humedo: @plant.peso_humedo&.to_f },
        pesaje:    { id: pesaje.id, peso_total_g: total_peso.to_f, plantas_count: count },
        progreso:  { pesadas: count, total: lote.plants.count,
                     peso_total_g: total_peso.to_f, completado: count >= lote.plants.count },
      }
    end
  end

  # DELETE /plants/:id/fotos/:blob_id
  def remove_foto
    blob = @plant.fotos.blobs.find_by(id: params[:blob_id])
    return render json: { error: 'Foto no encontrada' }, status: :not_found unless blob
    blob.attachments.where(record: @plant, name: 'fotos').each(&:purge)
    head :no_content
  end

  private

  def set_plant
    club   = current_user.club
    @plant = Plant.joins(:lote)
                  .where(lotes: { club_id: club.id })
                  .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Planta no encontrada' }, status: :not_found
  end

  def plant_params
    params.require(:plant).permit(
      :nombre, :lote_id, :genetica_id, :state, :origen,
      :fecha_germinacion, :fecha_vegetativo,
      :fecha_floracion, :fecha_cosecha,
      :peso_seco, :notas, :es_seleccion
    )
  end

  def attach_foto(plant)
    plant.foto.attach(params[:foto])
  rescue => e
    Rails.logger.warn "Error adjuntando foto a planta: #{e.message}"
  end

  def foto_url(plant)
    # Las fotos de planta se suben a `fotos` (has_many). Mantenemos compat con `foto`
    # (has_one) por si alguna quedó así. Devolvemos la más reciente.
    if plant.respond_to?(:foto) && plant.foto.attached?
      url_for(plant.foto)
    elsif plant.respond_to?(:fotos) && plant.fotos.attached?
      url_for(plant.fotos.blobs.order(created_at: :desc).first)
    end
  rescue
    nil
  end

  def dias_en_fase(plant)
    ref = case plant.state
          when 'semilla'    then plant.fecha_germinacion || plant.created_at.to_date
          when 'esqueje'    then plant.created_at.to_date
          when 'vegetativo' then plant.fecha_vegetativo || plant.created_at.to_date
          when 'floracion'  then plant.fecha_floracion
          when 'maduracion' then plant.fecha_floracion
          when 'cosechado'  then plant.fecha_cosecha
          end
    ref ? (Date.today - ref.to_date).to_i : nil
  end

  def serialize_plant(plant)
    g = plant.lote.genetica
    {
      id:           plant.id,
      club_id:      plant.lote.club_id,
      nombre:       plant.nombre,
      codigo_qr:    plant.codigo_qr,
      state:        plant.state,
      origen:       plant.origen,
      es_seleccion: plant.es_seleccion,
      peso_seco:    plant.peso_seco,
      peso_humedo:  plant.peso_humedo,
      foto_url:     foto_url(plant),
      lote: {
        id:     plant.lote.id,
        codigo: plant.lote.codigo,
        estado: plant.lote.estado,
        sala:   plant.lote.sala ? { id: plant.lote.sala.id, nombre: plant.lote.sala.nombre } : nil,
      },
      genetica:      g ? { id: g.id, nombre: g.nombre, tipo: g.tipo } : nil,
      created_at:    plant.created_at,
      dias_en_fase:  dias_en_fase(plant),
    }
  end

  def serialize_plant_detail(plant)
    g = plant.lote.genetica
    {
      id:        plant.id,
      nombre:    plant.nombre,
      codigo_qr: plant.codigo_qr,
      state:     plant.state,
      origen:    plant.origen,
      foto_url:  foto_url(plant),
      lote: {
        id:              plant.lote.id,
        codigo:          plant.lote.codigo,
        estado:          plant.lote.estado,
        genetica_id:     plant.lote.genetica_id,
        manicurador_id:  plant.lote.manicurador_id,
        plants_count:    plant.lote.plants_count,
        # Los lotes finalizados quedan sin sala (sala_id: nil) — nil-safe para no romper.
        sala: plant.lote.sala ? {
          id:     plant.lote.sala.id,
          nombre: plant.lote.sala.nombre,
          sede:   plant.lote.sala.sede ? { id: plant.lote.sala.sede_id, nombre: plant.lote.sala.sede.nombre } : nil,
        } : nil,
      },
      genetica: g ? { id: g.id, nombre: g.nombre, tipo: g.tipo, thc: g.thc, cbd: g.cbd } : nil,
      fecha_germinacion:      plant.fecha_germinacion,
      fecha_vegetativo:       plant.fecha_vegetativo,
      fecha_floracion:        plant.fecha_floracion,
      fecha_cosecha:          plant.fecha_cosecha,
      peso_seco:              plant.peso_seco,
      peso_humedo:            plant.peso_humedo,
      notas:                  plant.notas,
      dias_desde_germinacion: plant.fecha_germinacion ? (Date.today - plant.fecha_germinacion).to_i : nil,
      dias_en_vegetativo:     (plant.fecha_vegetativo && plant.fecha_floracion) ? (plant.fecha_floracion - plant.fecha_vegetativo).to_i : nil,
      dias_en_floracion:      (plant.fecha_floracion  && plant.fecha_cosecha)   ? (plant.fecha_cosecha  - plant.fecha_floracion).to_i  : nil,
      fotos:      plant.fotos.blobs.order(created_at: :desc).map { |b| serialize_blob(b) },
      created_at: plant.created_at,
      updated_at: plant.updated_at,
    }
  end

  def serialize_blob(blob)
    {
      id:               blob.id,
      filename:         blob.filename.to_s,
      url:              url_for(blob),
      descripcion:      blob.metadata['descripcion'],
      content_type:     blob.content_type,
      created_at_label: blob.created_at.strftime('%d/%m/%Y %H:%M'),
    }
  rescue
    nil
  end
end

