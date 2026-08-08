class WebhookJob < ApplicationJob
  queue_as :ambiente

  discard_on ActiveRecord::RecordNotFound

  def perform(dispositivo_id, payload)
    dispositivo = Dispositivo.activos.find(dispositivo_id)
    # Defensa en profundidad: la puerta es el webhook, pero un job encolado puede ejecutarse
    # después de que el club apagó IoT.
    return unless dispositivo.club&.feature?(:iot)

    ActsAsTenant.with_tenant(dispositivo.club) do
      driver_class = driver_para(dispositivo.tipo)
      driver_class.new(dispositivo).persist!(payload)
      EvaluarReglasJob.perform_later(dispositivo.sala_id)
    end
  end

  private

  def driver_para(tipo)
    case tipo
    when 'generic'   then Sensors::GenericDriver
    when 'sonoff_th' then Sensors::SonoffDriver
    else
      klass_name = "Sensors::#{tipo.camelize}Driver"
      klass_name.constantize rescue Sensors::GenericDriver
    end
  end
end
