class LoteEventosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_lote

  # Cultivador puede ver el historial de sus lotes
  skip_before_action :require_admin_o_agricultor, raise: false

  def index
    eventos = @lote.lote_eventos.recientes.limit(50)
    render json: eventos.map { |e| serialize(e) }
  end

  def create
    # Solo admin/agricultor puede crear eventos de cambio de ciclo
    if params.dig(:lote_evento, :tipo) == 'cambio_estado' && !current_user.admin_or_agricultor?
      render json: { error: 'No autorizado' }, status: :forbidden and return
    end

    evento = @lote.lote_eventos.build(evento_params)
    evento.user = current_user
    evento.club = current_user.club
    evento.registrado_en ||= Time.current

    if evento.tipo == 'cambio_estado' && evento.estado_nuevo.present?
      estado_anterior = @lote.estado
      if @lote.update(estado: evento.estado_nuevo)
        evento.estado_anterior = estado_anterior
      else
        render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
        return
      end
    end

    if evento.save
      render json: serialize(evento), status: :created
    else
      render json: { errors: evento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def evento_params
    params.require(:lote_evento).permit(:tipo, :estado_nuevo, :descripcion, :registrado_en)
  end

  def serialize(e)
    {
      id:              e.id,
      tipo:            e.tipo,
      estado_anterior: e.estado_anterior,
      estado_nuevo:    e.estado_nuevo,
      descripcion:     e.descripcion,
      registrado_en:   e.registrado_en,
      usuario:         e.user.nombre_completo,
      created_at:      e.created_at
    }
  end
end
