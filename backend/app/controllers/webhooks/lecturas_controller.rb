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

      # La organización puede haber apagado IoT (o haberse dado de baja) sin que nadie desenchufe el
      # sensor: el hardware sigue posteando. Se rechaza acá y no se ingiere nada — aceptar y
      # descartar en silencio dejaría a la organización generando lecturas, reglas y alertas de un
      # módulo que no tiene. 403 explícito para que el dispositivo no lo tome por caída.
      club = @dispositivo.club
      unless club&.activo? && !club.eliminado? && club.feature?(:iot)
        render json: { error: 'Ambiente / IoT no está habilitado para esta organización' },
               status: :forbidden and return
      end

      @dispositivo.touch(:ultima_lectura_at)
    end

    def payload_params
      params.to_unsafe_h.except('controller', 'action', 'dispositivo_id', 'format')
    end
  end
end
