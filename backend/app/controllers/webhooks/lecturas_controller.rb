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
      params.to_unsafe_h.except('controller', 'action', 'dispositivo_id', 'format')
    end
  end
end
