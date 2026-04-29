class GeneticasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_for_write!, only: [:create, :update, :destroy, :destroy_foto]
  before_action :set_genetica, only: [:show, :update, :destroy, :destroy_foto]

  # GET /geneticas
  def index
    club      = current_user.club
    scope     = Genetica.where(global: true)
    scope     = scope.or(Genetica.where(club_id: club.id)) if club
    scope     = scope.where(activa: true)
    scope     = scope.where(disponible: true) if params[:disponible].present?
    geneticas = scope.order(registrada_inase: :desc, nombre: :asc)
    render json: geneticas.map { |g| serialize_genetica(g, club) }
  end

  # GET /geneticas/:id
  def show
    render json: serialize_genetica_detail(@genetica)
  end

  # POST /geneticas
  def create
    genetica = Genetica.new(genetica_params)
    is_global = current_user.super_admin? && params[:genetica][:global].present?
    genetica.global   = is_global
    genetica.club_id  = is_global ? nil : current_user.club_id
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

  # DELETE /geneticas/:id/fotos/:foto_id
  def destroy_foto
    foto = @genetica.fotos.find { |f| f.id.to_s == params[:foto_id].to_s }
    return render json: { error: 'Foto no encontrada' }, status: :not_found unless foto
    foto.purge
    head :no_content
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
    club = current_user.club
    scope = Genetica.where(global: true)
    scope = scope.or(Genetica.where(club_id: club.id)) if club
    @genetica = scope.find(params[:id])
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
         .where(lotes: { club_id: club.id, genetica_id: genetica.id })
         .where.not(plants: { state: %w[cosechado descartada] })
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
      club_id:          genetica.club_id,
      global:           genetica.global,
      nombre:           genetica.nombre,
      slug:             genetica.slug,
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
    lotes_historicos = genetica.lotes.includes(:sala).order(start_date: :desc).limit(50).map do |l|
      peso = l.plants.where.not(peso_seco: nil).sum(:peso_seco).to_f
      {
        id:              l.id,
        codigo:          l.codigo,
        estado:          l.estado,
        start_date:      l.start_date,
        fecha_cosecha:   l.plants.maximum(:fecha_cosecha),
        sala:            l.sala&.nombre,
        plants_count:    l.plants_count,
        peso_seco_total: peso.positive? ? peso.round(2) : nil,
        rendimiento_gramos_planta: (peso.positive? && l.plants_count.to_i > 0) ? (peso / l.plants_count).round(1) : nil,
      }
    end
    {
      id:               genetica.id,
      club_id:          genetica.club_id,
      global:           genetica.global,
      nombre:           genetica.nombre,
      slug:             genetica.slug,
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
      visible_web:      genetica.visible_web,
      fotos:            genetica.fotos.attached? ? genetica.fotos.map { |f| { id: f.id, url: url_for(f) } } : [],
      plantas_count:    plantas_count(genetica, club),
      lotes_historicos: lotes_historicos,
      created_at:       genetica.created_at,
      updated_at:       genetica.updated_at,
    }
  end
end