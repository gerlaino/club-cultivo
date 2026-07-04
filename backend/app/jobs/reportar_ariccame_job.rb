class ReportarAriccameJob < ApplicationJob
  queue_as :default

  def perform(dispensacion_id)
    dispensacion = Dispensacion.find_by(id: dispensacion_id)
    return unless dispensacion
    return if dispensacion.ariccame_reportada?

    ActsAsTenant.with_tenant(dispensacion.stock&.club) do
      Ariccame::ReportadorDispensacion.new(dispensacion).call
    end
  rescue => e
    Rails.logger.error "ReportarAriccameJob failed for dispensacion #{dispensacion_id}: #{e.message}"
  end
end
