module Webhooks
  class LecturasController < ActionController::API
    include AutenticaDispositivo

    def create
      WebhookJob.perform_later(@dispositivo.id, payload_params)
      render json: { recibido: true }, status: :accepted
    end

    private

    def payload_params
      params.to_unsafe_h.except('controller', 'action', 'dispositivo_id', 'format')
    end
  end
end
