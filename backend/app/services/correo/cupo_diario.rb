module Correo
  # Cuántos mails más puede mandar hoy una organización.
  #
  # Cada una manda por SU casilla: con una contraseña de aplicación de Gmail el techo real es
  # ~500 destinatarios por día (2000 en Workspace). Pasarse no nos afecta a nosotros — le
  # SUSPENDEN LA CUENTA al cliente, y con ella se cae también el mail de bienvenida y todo lo
  # demás. Por eso el tope es propio y queda por debajo del de Google.
  class CupoDiario
    LIMITE = 450

    def self.usado(club)
      MailEnviado.where(club_id: club.id, enviado_at: Time.zone.today.all_day).count +
        EnvioMasivo.where(club_id: club.id, destino: 'libre')
                   .where(created_at: Time.zone.today.all_day).sum(:enviados) +
        (club.email_propio? ? portal_hoy(club) : 0)
    end

    # Los links del portal que salieron hoy por mail (invitaciones y «me olvidé la clave»). Cuentan
    # en el cupo de la organización sólo si salen por SU casilla (`AccesoMailer#portal_link`); si no
    # la conectó, salen por la de la plataforma. El mail de la ficha está cifrado: se mira en Ruby.
    def self.portal_hoy(club)
      ActsAsTenant.with_tenant(club) do
        AccesoPortal.where(club_id: club.id, created_at: Time.zone.today.all_day)
                    .includes(:paciente).count { |a| a.paciente&.email.present? }
      end
    end

    def self.restante(club) = [LIMITE - usado(club), 0].max

    def self.alcanza?(club, cuantos) = cuantos <= restante(club)
  end
end
