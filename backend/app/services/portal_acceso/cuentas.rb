# Las cuentas del portal que corresponden a un DNI. Es UN lugar porque lo preguntan las tres
# puertas sin sesión (entrar, «me olvidé la clave», activar un link) y tienen que contestar lo
# mismo: si una dejaba pasar a un paciente dado de baja y otra no, la regla vivía en dos lados.
#
# Una persona puede ser paciente en más de una organización: tiene una ficha y una cuenta en cada
# una, con su clave. Entra con DNI y clave; si la clave le sirve en más de una, elige a cuál DESPUÉS
# de validar (Germán, 23-oct): mostrar la lista antes le decía a cualquiera que tipeara un DNI en
# qué organizaciones es paciente esa persona.
module PortalAcceso
  module Cuentas
    module_function

    # Las fichas que pueden entrar al portal con este DNI: activas, en una organización vigente que
    # tiene el portal contratado y abierto. Sin tenant: la entrada no tiene sesión.
    #
    # `organizacion` (su slug) es la puerta de UNA organización, `/paciente/<slug>` (28-oct-2026,
    # Germán: «abrí el portal de Club Modelo y me llegó el mail de Mitocondria, y entré a
    # Mitocondria»). Por esa puerta todo queda en ella: el link que se manda, la cuenta en la que
    # entra. Un slug que no existe o con el portal cerrado no encuentra nada, como un DNI que no está.
    def fichas(dni, organizacion: nil)
      normalizado = dni.to_s.gsub(/\D/, '')
      return [] if normalizado.length < 6

      ActsAsTenant.without_tenant do
        alcance = Paciente.where(dni_normalizado: normalizado, es_paciente: true).where.not(aprobado_at: nil)
        if organizacion.present?
          club = puerta(organizacion)
          return [] unless club

          alcance = alcance.where(club_id: club.id)
        end
        alcance.includes(:club, :user)
               .select { |p| p.club && p.club.deleted_at.nil? && p.club.portal_paciente_disponible? }
      end
    end

    # La organización de una puerta, si tiene el portal abierto. Sin tenant (no hay sesión).
    def puerta(slug)
      return nil if slug.blank?

      club = ActsAsTenant.without_tenant { Club.find_by(slug: slug.to_s, deleted_at: nil) }
      club if club&.portal_paciente_disponible?
    end

    # Las cuentas en las que esta clave es la correcta. Se prueba en todas aunque la primera
    # acierte: cuánto tarda la respuesta no tiene que decir cuántas organizaciones hay.
    def con_clave(dni, password, organizacion: nil)
      fichas(dni, organizacion:).filter_map do |ficha|
        user = ficha.user
        user if user && user.valid_password?(password.to_s)
      end
    end

    def ficha_de(user)
      ActsAsTenant.without_tenant { Paciente.find_by(user_id: user.id) }
    end
  end
end
