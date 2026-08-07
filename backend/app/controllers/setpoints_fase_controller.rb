class SetpointsFaseController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :require_cultivador_or_admin
  before_action :require_admin!, only: [:create, :update, :destroy]
  before_action :set_setpoint, only: [:show, :update, :destroy]

  def index
    setpoints = SetpointFase.del_club(current_user.club_id)
    setpoints = setpoints.para_fase(params[:fase]) if params[:fase].present?
    render json: setpoints.map { |s| serialize(s) }
  end

  def show
    render json: serialize(@setpoint)
  end

  def create
    setpoint = SetpointFase.new(setpoint_params.merge(club_id: current_user.club_id))
    if setpoint.save
      render json: serialize(setpoint), status: :created
    else
      render json: { errors: setpoint.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @setpoint.update(setpoint_params)
      render json: serialize(@setpoint)
    else
      render json: { errors: @setpoint.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @setpoint.destroy
    head :no_content
  end

  private

  def set_setpoint
    @setpoint = SetpointFase.del_club(current_user.club_id).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Setpoint no encontrado' }, status: :not_found
  end

  def setpoint_params
    params.require(:setpoint_fase).permit(
      :fase, :tipo_lectura, :valor_min, :valor_max, :valor_ideal, :genetica_id
    )
  end

  def require_cultivador_or_admin
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin? || current_user.cultivador?
  end

  def require_admin!
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin?
  end

  def serialize(s)
    {
      id:             s.id,
      fase:           s.fase,
      tipo_lectura:   s.tipo_lectura,
      unidad:         s.unidad,
      valor_min:      s.valor_min,
      valor_max:      s.valor_max,
      valor_ideal:    s.valor_ideal,
      genetica_id:    s.genetica_id,
    }
  end
end
