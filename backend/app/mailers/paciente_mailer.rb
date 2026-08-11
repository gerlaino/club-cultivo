# Mail que la organización le manda a una persona: un paciente desde su ficha, o cualquier
# destinatario desde un envío masivo (un proveedor, por ejemplo).
#
# Las dos formas comparten la MISMA plantilla visual —encabezado con el logo y el nombre de la
# organización, cuerpo, firma—: para quien lo recibe es un mail de la organización y nada más.
class PacienteMailer < ApplicationMailer
  # Envío ligado a un paciente: queda registrado en su historial (`MailEnviado`).
  def mensaje(mail_enviado:)
    @club         = mail_enviado.club
    @remitente    = mail_enviado.user
    @asunto       = mail_enviado.asunto
    @cuerpo       = mail_enviado.cuerpo
    @destino      = mail_enviado.email_destino
    @destinatario = mail_enviado.paciente&.nombre_completo
    # Se mantienen por compatibilidad con lo que ya leía la vista.
    @mail_enviado = mail_enviado
    @paciente     = mail_enviado.paciente

    mail_para_club(@club, to: @destino, subject: @asunto)
  end

  # Envío a una dirección suelta, sin paciente detrás. No hay historial que actualizar: el
  # rastro queda en el envío masivo que lo originó.
  def libre(club:, remitente:, to:, asunto:, cuerpo:, destinatario: nil)
    @club         = club
    @remitente    = remitente
    @asunto       = asunto
    @cuerpo       = cuerpo
    @destino      = to
    @destinatario = destinatario

    mail_para_club(club, to: to, subject: asunto)
  end
end
