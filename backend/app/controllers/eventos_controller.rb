class EventosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_evento, only: [:show, :update, :destroy]

  def index
    eventos = current_user.club.eventos.ordenados
    render json: { data: eventos.map { |e| serialize(e) } }
  end

  def show
    render json: { data: serialize(@evento) }
  end

  def create
    evento = current_user.club.eventos.build(evento_params)
    if params[:imagen].present?
      evento.imagenes.attach(params[:imagen])
    end
    if evento.save
      render json: { data: serialize(evento) }, status: :created
    else
      render json: { errors: evento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if params[:imagen].present?
      @evento.imagenes.attach(params[:imagen])
    end
    if @evento.update(evento_params)
      render json: { data: serialize(@evento) }
    else
      render json: { errors: @evento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @evento.destroy
    head :no_content
  end

  private

  def set_evento
    @evento = current_user.club.eventos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Evento no encontrado' }, status: :not_found
  end

  def evento_params
    params.require(:evento).permit(:titulo, :descripcion, :fecha_inicio, :fecha_fin, :lugar, :activo)
  end

  def serialize(e)
    {
      id:           e.id,
      titulo:       e.titulo,
      descripcion:  e.descripcion,
      fecha_inicio: e.fecha_inicio,
      fecha_fin:    e.fecha_fin,
      lugar:        e.lugar,
      activo:       e.activo,
      imagen_url:   e.imagenes.attached? ? url_for(e.imagenes.first) : nil,
      created_at:   e.created_at,
      updated_at:   e.updated_at,
    }
  end

  def require_admin!
    unless current_user.admin? || current_user.super_admin?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end
end