# backend/app/controllers/costo_lotes_controller.rb
class CostoLotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_agricultor
  before_action :set_lote

  # GET /lotes/:lote_id/costo
  def show
    costo = @lote.costo_lote
    if costo
      render json: serialize(costo)
    else
      render json: { costo: nil, mensaje: "Sin costo calculado para este lote" }
    end
  end

  # POST /lotes/:lote_id/costo
  def create
    costo = @lote.build_costo_lote(costo_params)
    costo.club         = current_user.club
    costo.calculado_por = current_user
    costo.calculado_at  = Time.current

    if costo.save
      render json: serialize(costo), status: :created
    else
      render json: { errors: costo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /lotes/:lote_id/costo
  def update
    costo = @lote.costo_lote || @lote.build_costo_lote
    costo.club          ||= current_user.club
    costo.calculado_por  = current_user
    costo.calculado_at   = Time.current

    if costo.update(costo_params)
      render json: serialize(costo)
    else
      render json: { errors: costo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Lote no encontrado" }, status: :not_found
  end

  def costo_params
    params.require(:costo_lote).permit(
      :costo_insumos, :costo_energia, :costo_mano_obra,
      :costo_prorrateado, :gramos_producidos, :notas
    )
  end

  def require_admin_or_agricultor
    unless current_user.admin? || current_user.agricultor?
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end

  def serialize(c)
    {
      id:               c.id,
      lote_id:          c.lote_id,
      costo_insumos:    c.costo_insumos.to_f,
      costo_energia:    c.costo_energia.to_f,
      costo_mano_obra:  c.costo_mano_obra.to_f,
      costo_prorrateado: c.costo_prorrateado.to_f,
      costo_total:      c.costo_total.to_f,
      gramos_producidos: c.gramos_producidos&.to_f,
      costo_por_gramo:  c.costo_por_gramo&.to_f,
      notas:            c.notas,
      calculado_por:    c.calculado_por&.first_name || c.calculado_por&.email,
      calculado_at:     c.calculado_at,
    }
  end
end