module Webhooks
  # La puerta de todo lo que manda un aparato (lecturas, riegos). El dispositivo se identifica por
  # PK + token secreto (global, cross-club); esa es la autorización.
  module AutenticaDispositivo
    extend ActiveSupport::Concern

    included do
      # Declarado ANTES del before_action para que el without_tenant envuelva también el lookup
      # del dispositivo. Sin usuario → sin tenant, y con require_tenant=true (TEN-01c) buscar
      # Dispositivo sin tenant explotaría. Quien escribe fija su propio tenant.
      around_action :sin_tenant_webhook
      before_action :autenticar_dispositivo
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
      # aparato: el hardware sigue posteando. Se rechaza acá y no se ingiere nada — aceptar y
      # descartar en silencio dejaría a la organización generando datos de un módulo que no tiene.
      # 403 explícito para que el dispositivo no lo tome por caída.
      club = @dispositivo.club
      unless club&.activo? && !club.eliminado? && club.feature?(:iot)
        render json: { error: 'Ambiente / IoT no está habilitado para esta organización' },
               status: :forbidden and return
      end

      @dispositivo.touch(:ultima_lectura_at)
    end
  end
end
