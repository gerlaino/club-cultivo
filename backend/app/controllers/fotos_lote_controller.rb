# Las fotos del lote (`LoteFoto`): la galería de la ficha y la línea de tiempo.
#
# `create` acepta la imagen como `imagen` o `foto` (el botón rápido del teléfono manda `foto`),
# más `tomada_el`, `etiquetas` (lista o "a,b"), `nota` y `plant_id`. `index` devuelve todo lo
# que la galería necesita para agrupar por semana y filtrar por etiqueta; la pantalla no calcula
# días ni fases: los manda el backend.
class FotosLoteController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :set_lote
  before_action :set_foto, only: [:update, :destroy, :portada]

  def index
    fotos = @lote.lote_fotos.cronologicas.includes(:plant, :user, imagen_attachment: :blob)
    render json: {
      fotos:      fotos.map { |f| serialize(f) },
      etiquetas:  LoteFoto::ETIQUETAS_SUGERIDAS.map { |e| { clave: e, label: LoteFoto::ETIQUETA_LABELS[e] || e } },
      # Las que la organización ya usó y no están en las sugeridas: quedan para la próxima.
      etiquetas_usadas: current_user.club.lote_fotos_etiquetas,
      inicio:     @lote.start_date,
      dia_actual: @lote.start_date ? (Time.zone.today - @lote.start_date).to_i + 1 : nil,
    }
  end

  def create
    imagen = params[:imagen] || params[:foto]
    return render json: { error: 'No se recibió ninguna foto' }, status: :unprocessable_entity if imagen.blank?

    foto = @lote.lote_fotos.new(foto_params.merge(club: current_user.club, user: current_user))
    foto.imagen.attach(imagen)
    if foto.save
      render json: serialize(foto), status: :created
    else
      render json: { errors: foto.errors.full_messages }, status: :unprocessable_entity
    end
  rescue RedisClient::CannotConnectError, Redis::CannotConnectError => e
    Rails.logger.warn "[fotos_lote] Redis no disponible: #{e.message}"
    render json: { error: 'No se pudo guardar la foto' }, status: :unprocessable_entity
  end

  def update
    if @foto.update(foto_params)
      render json: serialize(@foto)
    else
      render json: { errors: @foto.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @lote.update_column(:foto_portada_blob_id, nil) if @lote.foto_portada_blob_id == @foto.imagen.blob&.id
    @foto.imagen.purge_later
    @foto.destroy!
    head :no_content
  end

  # PATCH /lotes/:lote_id/fotos/:id/portada — la que se muestra en el slot del layout de la sala.
  def portada
    @lote.update_column(:foto_portada_blob_id, @foto.imagen.blob.id)
    render json: serialize(@foto)
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def set_foto
    @foto = @lote.lote_fotos.find_by(id: params[:id])
    render json: { error: 'Foto no encontrada' }, status: :not_found unless @foto
  end

  def foto_params
    p = params.permit(:tomada_el, :nota, :plant_id, :fase, etiquetas: []).to_h
    p['etiquetas'] = params[:etiquetas] if params[:etiquetas].is_a?(String)
    p
  end

  def serialize(f)
    blob = f.imagen.blob
    {
      id:          f.id,
      url:         url_for(f.imagen),
      # Sin `image_processing` en el Gemfile no hay variantes: la grilla usa la imagen entera
      # con `loading="lazy"`. Cuando se sume la gema (libvips en Render), acá va la miniatura.
      thumb_url:   url_for(f.imagen),
      filename:    blob&.filename.to_s,
      tomada_el:   f.tomada_el,
      dia:         f.dia_de_vida,
      semana:      f.semana,
      fase:        f.fase,
      etiquetas:   f.etiquetas,
      nota:        f.nota,
      plant:       f.plant && { id: f.plant.id, codigo: f.plant.codigo_qr, nombre: f.plant.nombre },
      usuario:     f.user&.first_name,
      es_portada:  blob && blob.id == @lote.foto_portada_blob_id,
      created_at:  f.created_at,
    }
  end
end
