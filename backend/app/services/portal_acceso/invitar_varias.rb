# El link del portal para quien es paciente en más de una organización y pidió el link desde la
# puerta general (`/paciente`) con un mismo mail: un link por organización y UN mail con un botón
# por cada una (28-oct-2026). Ver `PortalAccesoController#recuperar`.
#
# Cada link es el de siempre (`Invitar`, sin su mail): sirve una vez, vence y pide el DNI de ESA
# ficha. El mail sale por la casilla de la plataforma, nunca por la de una de las organizaciones.
module PortalAcceso
  class InvitarVarias
    # `fichas`: las del mismo paciente (mismo mail), en organizaciones distintas. El bloque dice el
    # motivo de cada una (invitación o clave nueva).
    def self.call(fichas, &motivo)
      items = fichas.filter_map do |ficha|
        ActsAsTenant.with_tenant(ficha.club) do
          resultado = Invitar.call(ficha, motivo: motivo.call(ficha), mandar_mail: false)
          next unless resultado.ok?

          { club: ficha.club, link: resultado.link, expira_at: resultado.expira_at,
            invita: !ficha.portal_activado? }
        end
      end
      return if items.empty?

      AccesoMailer.portal_varias(email: fichas.first.email, nombre: fichas.first.nombre.to_s.split.first,
                                 items: items).deliver_later
    rescue StandardError => e
      Rails.logger.warn("[portal] no se pudo mandar el mail de varias organizaciones: #{e.class} #{e.message}")
    end
  end
end
