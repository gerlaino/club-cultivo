class SalaCultivadoresController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_sala

  # GET /salas/:sala_id/cultivadores
  def index
    render json: @sala.cultivadores.map { |u| serialize_user(u) }
  end

  # POST /salas/:sala_id/cultivadores
  # body: { user_id: 123 }
  def create
    user = current_user.club.users.find(params[:user_id])

    unless user.cultivador?
      return render json: { error: 'El usuario debe ser cultivador' }, status: :unprocessable_entity
    end

    asignacion = @sala.sala_cultivadores.find_or_initialize_by(user: user)

    if asignacion.new_record?
      asignacion.save!
      render json: { message: "#{user.nombre_completo} asignado a #{@sala.nombre}" }, status: :created
    else
      render json: { message: 'Ya estaba asignado' }, status: :ok
    end
  end

  # DELETE /salas/:sala_id/cultivadores/:user_id
  def destroy
    asignacion = @sala.sala_cultivadores.find_by(user_id: params[:id])

    if asignacion
      asignacion.destroy
      render json: { message: 'Cultivador desasignado' }
    else
      render json: { error: 'Asignación no encontrada' }, status: :not_found
    end
  end

  private

  def set_sala
    @sala = current_user.club.salas.find(params[:sala_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def require_admin!
    unless current_user.admin? || current_user.agricultor?
      render json: { error: 'Sin permiso' }, status: :forbidden
    end
  end

  def serialize_user(u)
    {
      id: u.id,
      nombre_completo: u.nombre_completo,
      email: u.email,
      avatar_url: nil
    }
  end
end