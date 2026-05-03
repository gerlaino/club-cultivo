class AlertasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_read_access
  before_action :set_alerta, only: [:show, :reconocer, :resolver]

  def index
    alertas = Alerta.del_club(current_user.club_id).recientes
    alertas = alertas.no_resueltas if params[:solo_activas] == 'true'
    alertas = alertas.de_sala(params[:sala_id]) if params[:sala_id].present?
    render json: alertas.map { |a| serialize(a) }
  end

  def show
    render json: serialize(@alerta)
  end

  def reconocer
    return render json: { error: 'Forbidden' }, status: :forbidden unless write_access?

    @alerta.reconocer!(current_user)
    render json: serialize(@alerta)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def resolver
    return render json: { error: 'Forbidden' }, status: :forbidden unless write_access?

    @alerta.resolver!(current_user)
    render json: serialize(@alerta)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_alerta
    @alerta = Alerta.del_club(current_user.club_id).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Alerta no encontrada' }, status: :not_found
  end

  def require_read_access
    unless current_user.admin? || current_user.cultivador? || current_user.auditor?
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end

  def write_access?
    current_user.admin? || current_user.cultivador?
  end

  def serialize(a)
    {
      id:               a.id,
      estado:           a.estado,
      mensaje:          a.mensaje,
      prioridad:        a.regla&.prioridad,
      tipo_lectura:     a.regla&.tipo_lectura,
      sala_id:          a.sala_id,
      sala_nombre:      a.sala&.nombre,
      regla_nombre:     a.regla&.nombre,
      reconocida_at:    a.reconocida_at,
      resuelta_at:      a.resuelta_at,
      created_at:       a.created_at,
    }
  end
end
