class FotosLoteController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote

  def index
    fotos = @lote.fotos.blobs.order(created_at: :desc).map { |b| serialize(b) }
    render json: fotos
  end

  def create
    unless params[:foto].present?
      render json: { error: 'No se recibió ninguna foto' }, status: :unprocessable_entity and return
    end

    @lote.fotos.attach(params[:foto])
    blob = @lote.fotos.blobs.order(created_at: :desc).first

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

    blob.attachments.where(record: @lote, name: 'fotos').each(&:purge)
    head :no_content
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
      created_at_label: blob.created_at.strftime('%d/%m/%Y %H:%M'),
    }
  end
end
