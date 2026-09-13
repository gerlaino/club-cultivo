class ApplicationMailer < ActionMailer::Base
  default from: -> { Club::PLATFORM_FROM }
  layout "mailer"

  # Un link a la app desde un mail. `APP_HOST` es el host de la plataforma (sin protocolo, como lo
  # lee `default_url_options`); los templates lo pegaban a mano con un dominio viejo por defecto y
  # un path que no existía.
  helper_method :url_app
  def url_app(path)
    host = ENV['APP_HOST'].presence || 'cultivoespacial.com'
    host = "https://#{host}" unless host.start_with?('http')
    "#{host.chomp('/')}#{path}"
  end

  private

  # Arma y manda el mail desde la casilla propia del club. Si el club NO conectó su correo
  # (email + contraseña de app), NO se manda (NullMail = deliver es no-op). El correo del club
  # es requisito para enviar — no hay fallback de plataforma.
  def mail_para_club(club, **opts)
    return unless club&.email_propio?

    @club ||= club
    adjuntar_logo(club)
    opts[:from] ||= club.email_from
    opts[:delivery_method_options] ||= club.email_delivery_options
    mail(**opts)
  end

  # Logo del club embebido (inline/CID) para que se vea en el encabezado de todos los mails.
  def adjuntar_logo(club)
    return unless club.logo.attached?
    attachments.inline['logo'] = { mime_type: club.logo.content_type, content: club.logo.download }
  rescue => e
    Rails.logger.warn("[mailer logo] #{e.message}")
  end
end
