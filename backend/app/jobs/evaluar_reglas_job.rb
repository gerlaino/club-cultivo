class EvaluarReglasJob < ApplicationJob
  queue_as :ambiente

  discard_on ActiveRecord::RecordNotFound

  def perform(sala_id)
    sala = Sala.find(sala_id)
    Ambiente::EvaluadorReglas.call(sala)
  end
end
