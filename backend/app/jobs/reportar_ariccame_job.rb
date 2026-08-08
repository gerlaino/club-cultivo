class ReportarAriccameJob < ApplicationJob
  queue_as :default

  def perform(dispensacion_id)
    dispensacion = Dispensacion.find_by(id: dispensacion_id)
    return unless dispensacion
    return if dispensacion.ariccame_reportada?

    # Reportar a un organismo regulador es lo último que debería seguir pasando solo: si el
    # club apagó ARICCAME entre que se encoló el job y que corrió, no se transmite.
    club = dispensacion.stock&.club
    return unless club&.feature?(:ariccame)

    ActsAsTenant.with_tenant(club) do
      Ariccame::ReportadorDispensacion.new(dispensacion).call
    end
  rescue => e
    Rails.logger.error "ReportarAriccameJob failed for dispensacion #{dispensacion_id}: #{e.message}"
  end
end
