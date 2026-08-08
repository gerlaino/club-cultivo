class LoteEventosController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :set_lote

  # Cultivador puede ver el historial de sus lotes
  skip_before_action :require_admin_o_cultivador, raise: false

  def index
    eventos = @lote.lote_eventos.includes(:sala_origen, :sala_destino).recientes.limit(50)
    render json: eventos.map { |e| serialize(e) }
  end

  def create
    # Solo admin/cultivador puede crear eventos de cambio de ciclo
    if params.dig(:lote_evento, :tipo) == 'cambio_estado' && !current_user.admin_or_cultivador?
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

  # DELETE /api/lotes/:lote_id/lote_eventos/:id
  # Solo admin. Un cambio de fase (cambio_estado) se puede borrar SOLO si no es la fase
  # actual del lote: sirve para limpiar una transición accidental. El evento de la fase
  # vigente queda protegido (para corregir esa fase se usa Editar lote).
  def destroy
    unless current_user.admin?
      return render json: { error: 'Solo un administrador puede borrar eventos' }, status: :forbidden
    end

    evento = @lote.lote_eventos.find(params[:id])

    if evento.tipo == 'cambio_estado' && evento.estado_nuevo == @lote.estado
      return render json: {
        error: 'No se puede borrar el evento de la fase actual del lote. Para corregir la fase vigente, usá Editar lote.'
      }, status: :unprocessable_entity
    end

    evento.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Evento no encontrado' }, status: :not_found
  end

  # PATCH /api/lotes/:lote_id/lote_eventos/:id
  # Edita una nota/alerta manual (descripción y/o fecha). Mismo criterio que destroy:
  # solo admin, y los cambio_estado NO se editan acá (definen la fase del lote → se
  # corrigen con Editar lote).
  def update
    unless current_user.admin?
      return render json: { error: 'Solo un administrador puede editar eventos' }, status: :forbidden
    end

    evento = @lote.lote_eventos.find(params[:id])

    if evento.tipo == 'cambio_estado'
      return render json: {
        error: 'Este evento define la fase del lote. Para corregir una fase, usá Editar lote (estado y fechas).'
      }, status: :unprocessable_entity
    end

    if evento.update(evento_update_params)
      render json: serialize(evento)
    else
      render json: { errors: evento.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Evento no encontrado' }, status: :not_found
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def evento_params
    params.require(:lote_evento).permit(:tipo, :estado_nuevo, :descripcion, :registrado_en, :categoria, metadata: {})
  end

  # En la edición se tocan descripción, fecha y el detalle (categoría + metadata) de
  # las actividades; nunca tipo/estado_nuevo.
  def evento_update_params
    params.require(:lote_evento).permit(:descripcion, :registrado_en, :categoria, metadata: {})
  end

  def serialize(e)
    {
      id:              e.id,
      tipo:            e.tipo,
      categoria:       e.categoria,
      categoria_label: e.categoria ? e.categoria_meta['label'] : nil,
      categoria_emoji: e.categoria ? e.categoria_meta['emoji'] : nil,
      metadata:        e.metadata || {},
      estado_anterior: e.estado_anterior,
      estado_nuevo:    e.estado_nuevo,
      descripcion:     e.descripcion,
      registrado_en:   e.registrado_en,
      usuario:         e.user&.nombre_completo || 'Sistema',
      created_at:      e.created_at,
      sala_origen:     e.sala_origen  ? { id: e.sala_origen.id,  nombre: e.sala_origen.nombre  } : nil,
      sala_destino:    e.sala_destino ? { id: e.sala_destino.id, nombre: e.sala_destino.nombre } : nil,
    }
  end
end
