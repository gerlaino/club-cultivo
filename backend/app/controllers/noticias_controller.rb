class NoticiasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_noticia, only: [:show, :update, :destroy]

  def index
    noticias = current_user.club.noticias.recientes
    render json: { data: noticias.map { |n| serialize(n) } }
  end

  def show
    render json: { data: serialize(@noticia) }
  end

  def create
    noticia = current_user.club.noticias.build(noticia_params)
    if params[:cover_image].present?
      noticia.cover_image.attach(params[:cover_image])
    end
    if noticia.save
      render json: { data: serialize(noticia) }, status: :created
    else
      render json: { errors: noticia.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if params[:cover_image].present?
      @noticia.cover_image.attach(params[:cover_image])
    end
    if @noticia.update(noticia_params)
      render json: { data: serialize(@noticia) }
    else
      render json: { errors: @noticia.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @noticia.destroy
    head :no_content
  end

  private

  def set_noticia
    @noticia = current_user.club.noticias.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Noticia no encontrada' }, status: :not_found
  end

  def noticia_params
    params.require(:noticia).permit(:titulo, :contenido, :publicada)
  end

  def serialize(n)
    {
      id:            n.id,
      titulo:        n.titulo,
      contenido:     n.contenido,
      publicada:     n.publicada,
      publicada_at:  n.publicada_at,
      cover_url:     n.cover_image.attached? ? url_for(n.cover_image) : nil,
      created_at:    n.created_at,
      updated_at:    n.updated_at,
    }
  end

  def require_admin!
    unless current_user.admin? || current_user.super_admin?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end
end