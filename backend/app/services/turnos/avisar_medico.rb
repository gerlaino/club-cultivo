# Le avisa al MÉDICO que administración le dio, le movió o le canceló un turno (Javi, 6-oct-2026):
# una push (si la tiene prendida, `turno_asignado` del catálogo) y un mail a su casilla real.
#
# No se avisa lo que hizo el propio médico. Al darle o moverle un turno, el turno queda «sin ver»
# (`visto_at` nil) hasta que el médico toca «Lo vi»: administración sabe si se enteró.
#
# El mail sale por el correo de la PLATAFORMA (como el «olvidé mi contraseña»), no por la casilla
# de la organización, y no lleva el motivo de la consulta: el nombre, el día y la hora alcanzan.
module Turnos
  module AvisarMedico
    TITULOS = {
      nuevo:     'Turno nuevo',
      movido:    'Te movieron un turno',
      cancelado: 'Te cancelaron un turno',
    }.freeze

    def self.call(turno, cambio:, por:)
      medico = turno.medico
      return if medico.nil? || por.nil? || por.id == medico.id

      cuando = I18n.l(turno.fecha_hora.in_time_zone('America/Argentina/Buenos_Aires'), format: '%a %d/%m %H:%M')
      PushNotificationService.notify_user_async(
        medico,
        tipo:  'turno_asignado',
        title: TITULOS.fetch(cambio),
        body:  "#{turno.paciente&.nombre_completo} · #{cuando}",
        url:   '/medico/turnos'
      )
      TurnosMailer.aviso_medico(turno: turno, cambio: cambio.to_s).deliver_later if medico.email_real.present?
    rescue StandardError => e
      # Un aviso que no sale no puede tirar abajo el turno que ya se guardó.
      Rails.logger.warn("[Turnos::AvisarMedico] turno #{turno&.id}: #{e.class} #{e.message}")
    end
  end
end
