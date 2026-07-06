class AlertasInternasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_alerta, only: [:marcar_leida]

  def index
    page  = (params[:pagina] || 1).to_i
    limit = (params[:limite] || 20).to_i

    alertas = scoped_alertas.recientes
    alertas = alertas.no_leidas if params[:solo_no_leidas].present?

    total          = alertas.count
    no_leidas_base = scoped_alertas.no_leidas
    alertas        = alertas.offset((page - 1) * limit).limit(limit)

    render json: {
      data: alertas.map { |a| serialize(a) },
      meta: { pagina: page, limite: limit, total: total,
              no_leidas: no_leidas_base.count }
    }
  end

  def marcar_leida
    @alerta.marcar_leida!
    render json: serialize(@alerta)
  end

  def marcar_todas_leidas
    scoped_alertas.no_leidas.update_all(leida_at: Time.current)
    render json: { ok: true }
  end

  private

  def scoped_alertas
    return AlertaInterna.none unless current_user.club
    base = current_user.club.alertas_internas
    return base if current_user.admin?
    base.where(destinada_a_role: current_user.role)
  end

  def set_alerta
    @alerta = scoped_alertas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Alerta no encontrada' }, status: :not_found
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
      entidad:          a.entidad,   # { tipo, id } para el deep-link del panel (nil si no aplica)
      created_at:       a.created_at,
    }
  end
end
