class ReglasAmbientalesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_regla, only: [:show, :update, :destroy]

  def index
    reglas = ReglaAmbiental.where(club: current_user.club).order(:nombre)
    render json: reglas.map { |r| serialize(r) }
  end

  def show
    render json: serialize(@regla)
  end

  def create
    regla = ReglaAmbiental.new(regla_params.merge(club: current_user.club))
    if regla.save
      render json: serialize(regla), status: :created
    else
      render json: { errors: regla.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @regla.update(regla_params)
      render json: serialize(@regla)
    else
      render json: { errors: @regla.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @regla.destroy
    head :no_content
  end

  private

  def set_regla
    @regla = ReglaAmbiental.find_by!(club: current_user.club, id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Regla no encontrada' }, status: :not_found
  end

  def regla_params
    params.require(:regla_ambiental).permit(
      :nombre, :tipo_lectura, :condicion, :umbral_a, :umbral_b,
      :duracion_minutos, :prioridad, :accion, :activa, :sala_id
    )
  end

  def require_admin!
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin?
  end

  def serialize(r)
    {
      id:                r.id,
      nombre:            r.nombre,
      tipo_lectura:      r.tipo_lectura,
      condicion:         r.condicion,
      umbral_a:          r.umbral_a,
      umbral_b:          r.umbral_b,
      duracion_minutos:  r.duracion_minutos,
      prioridad:         r.prioridad,
      accion:            r.accion,
      activa:            r.activa,
      sala_id:           r.sala_id,
    }
  end
end
