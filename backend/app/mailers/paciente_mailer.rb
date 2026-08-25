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

  # Su acceso al portal: usuario y contraseña.
  #
  # NO usa las plantillas que edita el admin, a propósito. Son texto libre con lista blanca de
  # variables: si alguien borra la variable de la contraseña, el paciente recibe un mail que no
  # sirve y nadie se entera. Este es fijo.
  #
  # La contraseña viaja en el mail y NO se guarda en el historial (ver `Pacientes::Acceso`): el
  # registro dice que se le mandó el acceso, no cuál es.
  def acceso_portal(paciente:, password:, club:, remitente:, nueva: false)
    @club      = club
    @remitente = remitente
    @paciente  = paciente
    @usuario   = paciente.user&.email
    @password  = password
    @nueva     = nueva
    # `App.base_url` y no un default escrito a mano: acá decía `https://app.cultivoespacial.com`,
    # un SUBDOMINIO, cuando la dirección elegida para la app es la raíz. Es el mail donde el
    # paciente recibe su contraseña — el link tiene que llevarlo a algún lado.
    @portal_url = "#{App.base_url}/portal"

    asunto = nueva ? "Tu nueva contraseña de #{club.name}" : "Tu acceso a #{club.name}"
    mail_para_club(club, to: paciente.email, subject: asunto)
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
