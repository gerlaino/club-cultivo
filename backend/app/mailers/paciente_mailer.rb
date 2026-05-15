class PacienteMailer < ApplicationMailer
  def mensaje(mail_enviado:)
    @mail_enviado = mail_enviado
    @paciente     = mail_enviado.paciente
    @club         = mail_enviado.club
    @remitente    = mail_enviado.user
    @cuerpo       = mail_enviado.cuerpo

    mail(
      to:      mail_enviado.email_destino,
      subject: mail_enviado.asunto
    )
  end
end
