module Bar
  # Puerta del evento (Capa 4): check-in de entradas por código QR y aforo en vivo.
  # Operan admin/supervisor/dispensador (el dispensador controla la puerta). Feature flag :bar.
  class PuertaController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :require_operador
    before_action :set_evento

    # GET .../puerta — aforo en vivo
    def estado
      render json: aforo
    end

    # POST .../puerta/checkin { codigo } — valida y marca la entrada como usada.
    def checkin
      codigo  = params[:codigo].to_s.strip
      entrada = @evento.entradas.find_by(codigo: codigo)

      return responder('invalida', 'Entrada no encontrada o inválida.', nil, :unprocessable_entity) if entrada.nil?
      return responder('anulada',  'Esta entrada fue anulada.', entrada, :unprocessable_entity) if entrada.estado == 'anulada'
      if entrada.estado == 'usada'
        return responder('duplicada', "Ya ingresó a las #{entrada.check_in_at&.strftime('%H:%M')}.", entrada, :unprocessable_entity)
      end
      if @evento.aforo.present? && adentro >= @evento.aforo
        return responder('aforo', 'Aforo completo.', entrada, :unprocessable_entity)
      end

      entrada.update!(estado: 'usada', check_in_at: Time.current)
      responder('ok', 'Ingreso válido.', entrada, :ok)
    end

    # POST .../puerta/revertir { codigo } — deshace un check-in (error en la puerta).
    def revertir
      entrada = @evento.entradas.find_by(codigo: params[:codigo].to_s.strip)
      return responder('invalida', 'Entrada no encontrada.', nil, :unprocessable_entity) if entrada.nil?

      entrada.update!(estado: 'valida', check_in_at: nil) if entrada.estado == 'usada'
      responder('ok', 'Ingreso revertido.', entrada, :ok)
    end

    private

    def set_evento
      @evento = current_user.club.bares.find(params[:bar_id]).eventos_bar.find(params[:evento_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Evento no encontrado' }, status: :not_found
    end

    def adentro  = @evento.entradas.where(estado: 'usada').count
    def vendidas = @evento.entradas.vigentes.count

    def aforo
      { adentro: adentro, vendidas: vendidas, aforo: @evento.aforo,
        no_show: [vendidas - adentro, 0].max }
    end

    def responder(resultado, mensaje, entrada, status)
      render json: {
        resultado: resultado, mensaje: mensaje,
        entrada: entrada && { codigo: entrada.codigo, comprador: entrada.comprador,
                              tipo: entrada.evento_bar_tipo_entrada&.nombre, estado: entrada.estado },
        aforo: aforo,
      }, status: status
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    def require_operador
      render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor dispensador].include?(current_user&.role)
    end
  end
end
