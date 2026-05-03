class AlertasInternasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_alerta, only: [:marcar_leida]

  def index
    page  = (params[:pagina] || 1).to_i
    limit = (params[:limite] || 20).to_i

    alertas = current_user.club.alertas_internas.recientes
    alertas = alertas.no_leidas if params[:solo_no_leidas].present?

    total   = alertas.count
    alertas = alertas.offset((page - 1) * limit).limit(limit)

    render json: {
      data: alertas.map { |a| serialize(a) },
      meta: { pagina: page, limite: limit, total: total,
              no_leidas: current_user.club.alertas_internas.no_leidas.count }
    }
  end

  def marcar_leida
    @alerta.marcar_leida!
    render json: serialize(@alerta)
  end

  private

  def set_alerta
    @alerta = current_user.club.alertas_internas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Alerta no encontrada' }, status: :not_found
  end

  def require_admin!
    render json: { error: 'No autorizado' }, status: :forbidden unless current_user&.admin?
  end

  def serialize(a)
    {
      id:               a.id,
      tipo:             a.tipo,
      mensaje:          a.mensaje,
      severidad:        a.severidad,
      leida:            a.leida?,
      leida_at:         a.leida_at,
      destinada_a_role: a.destinada_a_role,
      contexto:         a.contexto,
      created_at:       a.created_at,
    }
  end
end
