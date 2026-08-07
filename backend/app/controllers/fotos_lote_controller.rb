class FotosLoteController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :set_lote

  def index
    fotos = @lote.fotos.blobs.order(created_at: :desc).map { |b| serialize(b) }
    render json: fotos
  end

  def create
    unless params[:foto].present?
      return render json: { error: 'No se recibió ninguna foto' }, status: :unprocessable_entity
    end

    begin
      @lote.fotos.attach(params[:foto])
    rescue RedisClient::CannotConnectError, Redis::CannotConnectError => e
      Rails.logger.warn "[fotos_lote] Redis no disponible: #{e.message}"
    end

    blob = @lote.fotos.blobs.order(created_at: :desc).first
    return render json: { error: 'Error al guardar la foto' }, status: :unprocessable_entity unless blob

    if params[:descripcion].present?
      blob.update!(metadata: blob.metadata.merge('descripcion' => params[:descripcion].to_s.strip))
    end

    render json: serialize(blob), status: :created
  end

  def destroy
    blob = @lote.fotos.blobs.find_by(id: params[:id])
    unless blob
      render json: { error: 'Foto no encontrada' }, status: :not_found and return
    end

    # Si era la portada, se limpia (el método foto_portada_attachment ya cae a la última, pero
    # dejamos la columna consistente).
    @lote.update_column(:foto_portada_blob_id, nil) if @lote.foto_portada_blob_id == blob.id
    blob.attachments.where(record: @lote, name: 'fotos').each(&:purge)
    head :no_content
  end

  # PATCH /lotes/:lote_id/fotos/:id/portada — marca esta foto como portada del lote (la que
  # se muestra en el slot del layout de la sala).
  def portada
    blob = @lote.fotos.blobs.find_by(id: params[:id])
    return render json: { error: 'Foto no encontrada' }, status: :not_found unless blob

    @lote.update_column(:foto_portada_blob_id, blob.id)
    render json: serialize(blob)
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def serialize(blob)
    {
      id:           blob.id,
      filename:     blob.filename.to_s,
      url:          url_for(blob),
      descripcion:  blob.metadata['descripcion'],
      content_type: blob.content_type,
      lote_id:      @lote.id,
      es_portada:   blob.id == @lote.foto_portada_blob_id,
      created_at_label: blob.created_at.strftime('%d/%m/%Y %H:%M'),
    }
  end
end
