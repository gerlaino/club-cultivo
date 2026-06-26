class ApplicationMailer < ActionMailer::Base
  default from: -> { Club::PLATFORM_FROM }
  layout "mailer"

  private

  # Arma el mail con el "sobre" del club: remitente + reply-to + delivery según el modo
  # (plataforma-gestionado por defecto, o el SMTP propio del club si conectó su casilla).
  def mail_para_club(club, **opts)
    opts[:from] ||= club.email_from
    if (rt = club.email_reply_to)
      opts[:reply_to] ||= rt
    end
    if (dopts = club.email_delivery_options)
      opts[:delivery_method_options] ||= dopts
    end
    mail(**opts)
  end
end
