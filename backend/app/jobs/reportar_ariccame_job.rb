class ReportarAriccameJob < ApplicationJob
  queue_as :default

  def perform(dispensacion_id)
    dispensacion = Dispensacion.find_by(id: dispensacion_id)
    return unless dispensacion
    return if dispensacion.ariccame_reportada?

    Ariccame::ReportadorDispensacion.new(dispensacion).call
  rescue => e
    Rails.logger.error "ReportarAriccameJob failed for dispensacion #{dispensacion_id}: #{e.message}"
  end
end
