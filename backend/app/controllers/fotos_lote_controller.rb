class FotosLoteController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote

  def index
    fotos = @lote.fotos.map { |f| serialize(f) }
    render json: fotos
  end

  def create
    if params[:foto].present?
      @lote.fotos.attach(params[:foto])
      foto = @lote.fotos.last
      render json: serialize(foto), status: :created
    else
      render json: { error: 'No se recibió ninguna foto' }, status: :unprocessable_entity
    end
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def serialize(foto)
    {
      id:               foto.id,
      filename:         foto.filename.to_s,
      url:              url_for(foto),
      content_type:     foto.content_type,
      created_at_label: foto.created_at.strftime('%d/%m/%Y %H:%M')
    }
  end
end