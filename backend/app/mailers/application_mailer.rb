class ApplicationMailer < ActionMailer::Base
  default from: -> { Club::PLATFORM_FROM }
  layout "mailer"

  private

  # Arma y manda el mail desde la casilla propia del club. Si el club NO conectó su correo
  # (email + contraseña de app), NO se manda (NullMail = deliver es no-op). El correo del club
  # es requisito para enviar — no hay fallback de plataforma.
  def mail_para_club(club, **opts)
    return unless club&.email_propio?

    opts[:from] ||= club.email_from
    opts[:delivery_method_options] ||= club.email_delivery_options
    mail(**opts)
  end
end
