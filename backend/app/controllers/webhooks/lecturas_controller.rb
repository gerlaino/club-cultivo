module Webhooks
  class LecturasController < ActionController::API
    # Declarado ANTES del before_action para que el without_tenant envuelva también el
    # lookup del dispositivo. El dispositivo se identifica por PK + token secreto (global,
    # cross-club); esa es la autorización. Sin usuario → sin tenant, y con require_tenant=true
    # (TEN-01c) buscar Dispositivo sin tenant explotaría. El WebhookJob fija su propio tenant.
    around_action :sin_tenant_webhook
    before_action :autenticar_dispositivo

    def create
      WebhookJob.perform_later(@dispositivo.id, payload_params)
      render json: { recibido: true }, status: :accepted
    end

    private

    def sin_tenant_webhook
      ActsAsTenant.without_tenant { yield }
    end

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
