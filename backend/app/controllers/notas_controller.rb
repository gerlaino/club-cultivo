class NotasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_noteable

  def index
    notas = @noteable_notas.where(club: current_user.club).recientes
    render json: notas.map { |n| serialize(n) }
  end

  def create
    nota = @noteable_notas.build(
      contenido: params[:contenido].to_s.strip,
      fuente:    params[:fuente] || 'manual',
      club:      current_user.club,
      user:      current_user
    )
    return render json: { error: 'Contenido vacío' }, status: :unprocessable_entity if nota.contenido.blank?
    if nota.save
      render json: serialize(nota), status: :created
    else
      render json: { errors: nota.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    nota = current_user.club.notas.find(params[:id])
    nota.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Nota no encontrada' }, status: :not_found
  end

  private

  def set_noteable
    if params[:sala_id]
      noteable = current_user.club.salas.find(params[:sala_id])
      @noteable_notas = noteable.notas
    elsif params[:lote_id]
      noteable = current_user.club.lotes.find(params[:lote_id])
      @noteable_notas = noteable.notas
    elsif params[:plant_id]
      noteable = Plant.joins(:lote).where(lotes: { club_id: current_user.club.id }).find(params[:plant_id])
      @noteable_notas = noteable.observaciones
    else
      render json: { error: 'Contexto no encontrado' }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Recurso no encontrado' }, status: :not_found
  end

  def serialize(nota)
    {
      id:         nota.id,
      contenido:  nota.contenido,
      fuente:     nota.fuente,
      usuario:    nota.usuario,
      created_at: nota.created_at,
    }
  end
end
