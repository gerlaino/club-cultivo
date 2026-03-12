class GeneticasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_genetica, only: [:show, :update, :destroy]

  # GET /geneticas
  def index
    club = current_user.club
    geneticas = club.geneticas.where(activa: true).order(:nombre)

    render json: geneticas.map { |g| serialize_genetica(g) }
  end

  # GET /geneticas/:id
  def show
    render json: serialize_genetica_detail(@genetica)
  end

  # POST /geneticas
  def create
    genetica = current_user.club.geneticas.build(genetica_params)

    if genetica.save
      render json: serialize_genetica(genetica), status: :created
    else
      render json: { errors: genetica.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /geneticas/:id
  def update
    if @genetica.update(genetica_params)
      render json: serialize_genetica(@genetica)
    else
      render json: { errors: @genetica.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /geneticas/:id
  def destroy
    # Soft delete - marcar como inactiva
    @genetica.update(activa: false)
    head :no_content
  end

  private

  def set_genetica
    @genetica = current_user.club.geneticas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Genética no encontrada' }, status: :not_found
  end

  def genetica_params
    params.require(:genetica).permit(
      :nombre,
      :tipo,
      :thc,
      :cbd,
      :descripcion,
      :origen,
      :tiempo_floracion,
      :rendimiento,
      :altura,
      :dificultad,
      :activa,
      :disponible
    )
  end

  def serialize_genetica(genetica)
    {
      id: genetica.id,
      nombre: genetica.nombre,
      tipo: genetica.tipo,
      thc: genetica.thc,
      cbd: genetica.cbd,
      activa: genetica.activa,
      disponible: genetica.disponible
    }
  end

  def serialize_genetica_detail(genetica)
    {
      id: genetica.id,
      nombre: genetica.nombre,
      tipo: genetica.tipo,
      thc: genetica.thc,
      cbd: genetica.cbd,
      descripcion: genetica.descripcion,
      origen: genetica.origen,
      tiempo_floracion: genetica.tiempo_floracion,
      rendimiento: genetica.rendimiento,
      altura: genetica.altura,
      dificultad: genetica.dificultad,
      activa: genetica.activa,
      disponible: genetica.disponible,
      created_at: genetica.created_at,
      updated_at: genetica.updated_at
    }
  end
end