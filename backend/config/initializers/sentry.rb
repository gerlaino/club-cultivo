# Sentry: rendimiento (cuánto tarda cada pedido, qué consultas hace) y errores de producción.
#
# Queda APAGADO si no hay SENTRY_DSN: desarrollo, specs y cualquier entorno sin la variable no
# mandan nada. En Render: SENTRY_DSN (del proyecto en sentry.io) y, opcional,
# SENTRY_TRACES_SAMPLE_RATE (qué fracción de los pedidos se mide; 0.2 por defecto).
#
# Datos de salud: NUNCA se manda nada de la persona. Sin `send_default_pii` Sentry no adjunta
# cookies, cuerpo del pedido, IP ni usuario; los parámetros pasan por `filter_parameters`, y lo
# que identifica (DNI, nombres, mails) se borra de nuevo en `before_send` por si un mensaje de error
# lo trae adentro.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn                = ENV["SENTRY_DSN"]
    config.environment        = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release            = ENV["RENDER_GIT_COMMIT"]
    config.send_default_pii   = false
    config.breadcrumbs_logger = [:active_support_logger]
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.2").to_f
    # El health check lo pega el monitor externo cada minuto: medirlo es ruido y gasta la cuota.
    config.traces_sampler = lambda do |ctx|
      name = ctx.dig(:transaction_context, :name).to_s
      next 0.0 if name.match?(%r{\A/(api/)?(up|salud(/backup)?)\z}) || name.include?("HealthController")

      config.traces_sample_rate
    end
    config.excluded_exceptions += %w[ActionController::RoutingError ActiveRecord::RecordNotFound]

    filtro = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters + %i[dni nombre apellido telefono direccion])
    config.before_send = lambda do |event, _hint|
      if event.request
        event.request.data    = nil
        event.request.cookies = nil
      end
      event.extra = filtro.filter(event.extra) if event.extra.present?
      event
    end
  end
end
