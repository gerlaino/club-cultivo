class PacienteMailer < ApplicationMailer
  def mensaje(mail_enviado:)
    @mail_enviado = mail_enviado
    @paciente     = mail_enviado.paciente
    @club         = mail_enviado.club
    @remitente    = mail_enviado.user
    @cuerpo       = mail_enviado.cuerpo

    from_address = if @club.smtp_from.present?
      "#{@club.smtp_from_name.presence || @club.name} <#{@club.smtp_from}>"
    else
      "#{@club.name} <#{@club.smtp_user}>"
    end

    mail(
      to:      mail_enviado.email_destino,
      subject: mail_enviado.asunto,
      from:    from_address,
      delivery_method_options: @club.smtp_settings
    )
  end
end
