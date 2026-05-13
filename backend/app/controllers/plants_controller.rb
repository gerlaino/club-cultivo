class PlantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plant, only: [:show, :update, :destroy, :add_foto, :remove_foto]

  # GET /plants
  def index
    plants = Plant.joins(:lote).where(lotes: { club_id: current_user.club_id })
    if current_user.cultivador?
      salas_ids = current_user.salas_ids_asignadas
      return render json: [] if salas_ids.empty?
      plants = plants.where(lotes: { sala_id: salas_ids })
    elsif current_user.supervisor?
      salas_ids = current_user.salas_ids_en_sedes_asignadas
      return render json: [] if salas_ids.empty?
      plants = plants.where(lotes: { sala_id: salas_ids })
    end
    plants = plants.where(lote_id: params[:lote_id]) if params[:lote_id].present?
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
    @plant.fotos.attach(params[:foto])
    blob = @plant.fotos.blobs.order(created_at: :desc).first
    render json: serialize_blob(blob), status: :created
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
    return nil unless plant.respond_to?(:foto) && plant.foto.attached?
    url_for(plant.foto)
  rescue
    nil
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
      foto_url:     foto_url(plant),
      lote: {
        id:     plant.lote.id,
        codigo: plant.lote.codigo,
        estado: plant.lote.estado,
      },
      genetica: g ? { id: g.id, nombre: g.nombre, tipo: g.tipo } : nil,
      fecha_germinacion:      plant.fecha_germinacion,
      dias_desde_germinacion: plant.fecha_germinacion ? (Date.today - plant.fecha_germinacion).to_i : nil,
      created_at: plant.created_at,
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
        id:         plant.lote.id,
        codigo:     plant.lote.codigo,
        estado:     plant.lote.estado,
        genetica_id: plant.lote.genetica_id,
        sala: {
          id:     plant.lote.sala.id,
          nombre: plant.lote.sala.nombre,
          sede:   { id: plant.lote.sala.sede_id, nombre: plant.lote.sala.sede.nombre },
        },
      },
      genetica: g ? { id: g.id, nombre: g.nombre, tipo: g.tipo, thc: g.thc, cbd: g.cbd } : nil,
      fecha_germinacion:      plant.fecha_germinacion,
      fecha_vegetativo:       plant.fecha_vegetativo,
      fecha_floracion:        plant.fecha_floracion,
      fecha_cosecha:          plant.fecha_cosecha,
      peso_seco:              plant.peso_seco,
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
      content_type:     blob.content_type,
      created_at_label: blob.created_at.strftime('%d/%m/%Y %H:%M'),
    }
  rescue
    nil
  end
end

