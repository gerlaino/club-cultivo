module Webhooks
  class LecturasController < ActionController::API
    before_action :autenticar_dispositivo

    def create
      WebhookJob.perform_later(@dispositivo.id, payload_params)
      render json: { recibido: true }, status: :accepted
    end

    private

    def autenticar_dispositivo
      dispositivo_id = params[:dispositivo_id]
      token          = request.headers['X-Webhook-Token']

      @dispositivo = Dispositivo.activos.find_by(id: dispositivo_id)

      unless @dispositivo&.webhook_token_matches?(token)
        render json: { error: 'Unauthorized' }, status: :unauthorized and return
      end

      @dispositivo.touch(:ultima_lectura_at)
    end

    def payload_params
      params.permit(:temperatura, :humedad, :co2, :luminosidad, :ppfd, :ec, :ph,
                    :timestamp, :presion, :voc).to_h
    end
  end
end
