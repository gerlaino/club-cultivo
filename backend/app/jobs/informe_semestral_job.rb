class InformeSemestralJob < ApplicationJob
  queue_as :default

  # modo: :recordatorio (30 días antes) o :envio (al cierre del semestre)
  #
  # Este es el ÚNICO informe que se emite solo: los demás se calculan cuando alguien los abre
  # (no hay informes guardados en la base). Por eso es el único que se apaga con la suite —
  # consultar el histórico desde la app se sigue pudiendo, mandar un mail automático de un
  # módulo dado de baja, no. El contenido es mixto (pacientes + producción + dispensa): con
  # tener UNA de las dos suites, el informe todavía dice algo.
  def perform(modo = :envio)
    hoy      = Time.zone.today
    anio     = hoy.year
    semestre = hoy.month <= 6 ? 1 : 2

    cada_club_con(:cultivo, :produccion_dispensa) do |club|
      datos = InformeSemestralService.new(club, anio: anio, semestre: semestre).call
      NotificacionesMailer.informe_semestral(
        club:      club,
        datos:     datos,
        modo:      modo.to_sym,
        anio:      anio,
        semestre:  semestre
      ).deliver_now
    end
  end
end
