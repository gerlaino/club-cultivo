class EvaluarReglasJob < ApplicationJob
  queue_as :ambiente

  discard_on ActiveRecord::RecordNotFound

  def perform(sala_id)
    sala = Sala.find(sala_id)
    # Las reglas ambientales generan alertas: sin el add-on de IoT no hay a quién avisarle
    # de un módulo que el club no ve.
    return unless sala.club&.feature?(:iot)

    ActsAsTenant.with_tenant(sala.club) { Ambiente::EvaluadorReglas.call(sala) }
  end
end
