class WebhookJob < ApplicationJob
  queue_as :ambiente

  discard_on ActiveRecord::RecordNotFound

  def perform(dispositivo_id, payload)
    dispositivo = Dispositivo.activos.find(dispositivo_id)
    driver_class = driver_para(dispositivo.tipo)
    driver_class.new(dispositivo).persist!(payload)
    EvaluarReglasJob.perform_later(dispositivo.sala_id)
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
