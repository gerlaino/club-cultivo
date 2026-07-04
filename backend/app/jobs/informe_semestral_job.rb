class InformeSemestralJob < ApplicationJob
  queue_as :default

  # modo: :recordatorio (30 días antes) o :envio (al cierre del semestre)
  def perform(modo = :envio)
    hoy      = Date.today
    anio     = hoy.year
    semestre = hoy.month <= 6 ? 1 : 2

    Club.activos.find_each do |club|
      ActsAsTenant.with_tenant(club) do
        datos = InformeSemestralService.new(club, anio: anio, semestre: semestre).call
        NotificacionesMailer.informe_semestral(
          club:      club,
          datos:     datos,
          modo:      modo.to_sym,
          anio:      anio,
          semestre:  semestre
        ).deliver_later
      end
    rescue => e
      Rails.logger.error "InformeSemestralJob club #{club.id} (#{modo}): #{e.class}: #{e.message}"
    end
  end
end
