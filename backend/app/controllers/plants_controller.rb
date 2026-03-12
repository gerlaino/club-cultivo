class PlantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plant, only: [:show, :update, :destroy]

  # GET /plants
  def index
    club = current_user.club
    plants = Plant.where(lote_id: club.lotes.pluck(:id))

    # Filtros opcionales
    plants = plants.where(state: params[:state]) if params[:state].present?
    plants = plants.where(lote_id: params[:lote_id]) if params[:lote_id].present?

    render json: plants.map { |p| serialize_plant(p) }
  end

  # GET /plants/:id
  def show
    render json: serialize_plant_detail(@plant)
  end

  # POST /plants
  def create
    lote = current_user.club.lotes.find(params[:plant][:lote_id])
    plant = lote.plants.build(plant_params)

    if plant.save
      lote.increment!(:plants_count)
      render json: serialize_plant(plant), status: :created
    else
      render json: { errors: plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /plants/:id
  def update
    if @plant.update(plant_params)
      render json: serialize_plant(@plant)
    else
      render json: { errors: @plant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /plants/:id
  def destroy
    lote = @plant.lote
    @plant.destroy
    lote.decrement!(:plants_count) if lote.plants_count > 0
    head :no_content
  end

  private

  def set_plant
    club = current_user.club
    @plant = Plant.joins(:lote).where(lotes: { club_id: club.id }).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Planta no encontrada' }, status: :not_found
  end

  def plant_params
    params.require(:plant).permit(
      :nombre,
      :genetica_id,
      :state,
      :fecha_germinacion,
      :fecha_vegetativo,
      :fecha_floracion,
      :fecha_cosecha,
      :peso_seco,
      :notas
    )
  end

  def serialize_plant(plant)
    {
      id: plant.id,
      nombre: plant.nombre,
      codigo_qr: plant.codigo_qr,
      state: plant.state,
      lote: {
        id: plant.lote.id,
        code: plant.lote.code
      },
      genetica: plant.genetica ? {
        id: plant.genetica.id,
        nombre: plant.genetica.nombre,
        tipo: plant.genetica.tipo
      } : nil,
      fecha_germinacion: plant.fecha_germinacion,
      dias_desde_germinacion: plant.fecha_germinacion ? (Date.today - plant.fecha_germinacion).to_i : nil,
      created_at: plant.created_at
    }
  end

  def serialize_plant_detail(plant)
    {
      id: plant.id,
      nombre: plant.nombre,
      codigo_qr: plant.codigo_qr,
      state: plant.state,
      lote: {
        id: plant.lote.id,
        code: plant.lote.code,
        sala: {
          id: plant.lote.sala.id,
          name: plant.lote.sala.name
        }
      },
      genetica: plant.genetica ? {
        id: plant.genetica.id,
        nombre: plant.genetica.nombre,
        tipo: plant.genetica.tipo,
        thc: plant.genetica.thc,
        cbd: plant.genetica.cbd
      } : nil,
      fecha_germinacion: plant.fecha_germinacion,
      fecha_vegetativo: plant.fecha_vegetativo,
      fecha_floracion: plant.fecha_floracion,
      fecha_cosecha: plant.fecha_cosecha,
      peso_seco: plant.peso_seco,
      notas: plant.notas,
      dias_desde_germinacion: plant.fecha_germinacion ? (Date.today - plant.fecha_germinacion).to_i : nil,
      dias_en_vegetativo: plant.fecha_vegetativo && plant.fecha_floracion ? (plant.fecha_floracion - plant.fecha_vegetativo).to_i : nil,
      dias_en_floracion: plant.fecha_floracion && plant.fecha_cosecha ? (plant.fecha_cosecha - plant.fecha_floracion).to_i : nil,
      created_at: plant.created_at,
      updated_at: plant.updated_at
    }
  end
end