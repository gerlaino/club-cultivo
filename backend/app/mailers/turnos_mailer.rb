class TurnosMailer < ApplicationMailer
  # Al médico: le dieron, le movieron o le cancelaron un turno (`Turnos::AvisarMedico`). Un mail
  # por destinatario, sin el motivo de la consulta.
  def aviso_medico(turno:, cambio:)
    @turno  = turno
    @medico = turno.medico
    @club   = turno.club
    @cambio = cambio
    @cuando = I18n.l(turno.fecha_hora.in_time_zone('America/Argentina/Buenos_Aires'), format: '%A %d/%m a las %H:%M')
    @link   = url_app('/medico/turnos')
    @frase  = { 'nuevo' => "Administración de #{@club.name} te dio un turno nuevo:",
                'movido' => "Administración de #{@club.name} te movió un turno. Queda así:" }
              .fetch(cambio, "Administración de #{@club.name} canceló este turno:")
    adjuntar_logo(@club)
    asunto = { 'nuevo' => 'Tenés un turno nuevo', 'movido' => 'Te movieron un turno',
               'cancelado' => 'Te cancelaron un turno' }.fetch(cambio, 'Turno')
    mail(to: @medico.email_real, subject: "#{asunto} — #{@club.name}")
  end
end
