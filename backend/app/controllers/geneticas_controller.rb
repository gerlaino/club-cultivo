class GeneticasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_genetica, only: [:show, :update, :destroy]

  # GET /geneticas
  def index
    club      = current_user.club
    geneticas = club.geneticas.where(activa: true)
    geneticas = geneticas.where(disponible: true) if params[:disponible].present?
    geneticas = geneticas.order(registrada_inase: :desc, nombre: :asc)
    render json: geneticas.map { |g| serialize_genetica(g, club) }
  end

  # GET /geneticas/:id
  def show
    render json: serialize_genetica_detail(@genetica)
  end

  # POST /geneticas
  def create
    genetica = current_user.club.geneticas.build(genetica_params)
    if genetica.save
      attach_foto(genetica) if params[:foto].present?
      render json: serialize_genetica(genetica, current_user.club), status: :created
    else
      render json: { errors: genetica.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /geneticas/:id
  def update
    # Campos protegidos para genéticas INASE
    permitted = if @genetica.registrada_inase?
                  genetica_params.except(:nombre, :tipo, :thc, :cbd, :criador, :registrada_inase)
                else
                  genetica_params
                end

    if @genetica.update(permitted)
      attach_foto(@genetica) if params[:foto].present?
      render json: serialize_genetica(@genetica, current_user.club)
    else
      render json: { errors: @genetica.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /geneticas/:id → soft delete, bloqueado para INASE
  def destroy
    if @genetica.registrada_inase?
      return render json: { error: 'Las genéticas registradas en INASE no pueden eliminarse' }, status: :forbidden
    end
    @genetica.update(activa: false)
    head :no_content
  end

  private

  def set_genetica
    @genetica = current_user.club.geneticas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Genética no encontrada' }, status: :not_found
  end

  def attach_foto(genetica)
    genetica.fotos.attach(params[:foto])
  rescue => e
    Rails.logger.warn "Error adjuntando foto: #{e.message}"
  end

  def plantas_count(genetica, club)
    Plant.joins(:lote)
         .where(lotes: { club_id: club.id }, genetica_id: genetica.id)
         .count
  end

  def foto_url(genetica)
    return nil unless genetica.fotos.attached?
    url_for(genetica.fotos.first)
  rescue
    nil
  end

  def genetica_params
    params.require(:genetica).permit(
      :nombre, :tipo, :thc, :cbd, :descripcion,
      :origen, :tiempo_floracion, :rendimiento,
      :altura, :dificultad, :activa, :disponible,
      :registrada_inase, :criador, :terpenos, :visible_web
    )
  end

  def serialize_genetica(genetica, club)
    {
      id:               genetica.id,
      nombre:           genetica.nombre,
      tipo:             genetica.tipo,
      thc:              genetica.thc,
      cbd:              genetica.cbd,
      dificultad:       genetica.dificultad,
      disponible:       genetica.disponible,
      activa:           genetica.activa,
      registrada_inase: genetica.registrada_inase,
      criador:          genetica.criador,
      terpenos:         genetica.terpenos,
      visible_web:      genetica.visible_web,
      foto_url:         foto_url(genetica),
      plantas_count:    plantas_count(genetica, club),
    }
  end

  def serialize_genetica_detail(genetica)
    club = current_user.club
    {
      id:               genetica.id,
      nombre:           genetica.nombre,
      tipo:             genetica.tipo,
      thc:              genetica.thc,
      cbd:              genetica.cbd,
      descripcion:      genetica.descripcion,
      origen:           genetica.origen,
      tiempo_floracion: genetica.tiempo_floracion,
      rendimiento:      genetica.rendimiento,
      altura:           genetica.altura,
      dificultad:       genetica.dificultad,
      disponible:       genetica.disponible,
      activa:           genetica.activa,
      registrada_inase: genetica.registrada_inase,
      criador:          genetica.criador,
      terpenos:         genetica.terpenos,
      foto_url:         foto_url(genetica),
      plantas_count:    plantas_count(genetica, club),
      created_at:       genetica.created_at,
      updated_at:       genetica.updated_at,
    }
  end
end