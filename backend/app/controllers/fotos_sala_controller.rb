# Fotos de una SALA: el estado del cuarto, el montaje, un problema que hay que mostrar. Es el mismo
# patrón que `FotosLoteController`, sin portada —una sala no se muestra en el layout de otra—.
class FotosSalaController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sala

  def index
    render json: @sala.fotos.blobs.order(created_at: :desc).map { |b| serialize(b) }
  end

  def create
    return render json: { error: 'No se recibió ninguna foto' }, status: :unprocessable_entity if params[:foto].blank?

    begin
      @sala.fotos.attach(params[:foto])
    rescue RedisClient::CannotConnectError, Redis::CannotConnectError => e
      # El análisis de la imagen se encola en Redis. Si no está disponible, la foto igual quedó
      # guardada: no se pierde el trabajo del que la sacó.
      Rails.logger.warn "[fotos_sala] Redis no disponible: #{e.message}"
    end

    blob = @sala.fotos.blobs.order(created_at: :desc).first
    return render json: { error: 'Error al guardar la foto' }, status: :unprocessable_entity unless blob

    if params[:descripcion].present?
      blob.update!(metadata: blob.metadata.merge('descripcion' => params[:descripcion].to_s.strip))
    end

    render json: serialize(blob), status: :created
  end

  def destroy
    blob = @sala.fotos.blobs.find_by(id: params[:id])
    return render json: { error: 'Foto no encontrada' }, status: :not_found unless blob

    blob.attachments.where(record: @sala, name: 'fotos').each(&:purge)
    head :no_content
  end

  private

  def set_sala
    @sala = current_user.club.salas.find(params[:sala_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def serialize(blob)
    {
      id:               blob.id,
      filename:         blob.filename.to_s,
      url:              url_for(blob),
      descripcion:      blob.metadata['descripcion'],
      content_type:     blob.content_type,
      sala_id:          @sala.id,
      created_at_label: blob.created_at.strftime('%d/%m/%Y %H:%M'),
    }
  end
end
