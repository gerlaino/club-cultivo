# ¿Se le ofrece mandarle la invitación al portal a este paciente al dispensarle? (27-oct-2026)
#
# La invitación llega en la PRÓXIMA DISPENSA: es cuando el paciente está, y quien atiende le
# puede decir «te llegó un mail para entrar a tu portal». El modal muestra un tilde
# («Mandarle por mail cómo entrar a su portal») sólo si tiene sentido:
#
#   · el portal está contratado y abierto,
#   · el paciente está activo, admitido y tiene mail en la ficha,
#   · todavía no lo activó (no eligió su clave),
#   · y no tiene un link vigente (ya le llegó uno que todavía sirve).
#
# Viene TILDADO, salvo que ya se lo haya invitado en los últimos 30 días: un mail por cada visita
# hasta que lo active sería insistir de más. Ahí el tilde aparece igual, sin marcar, para el que
# quiera reenviarlo.
#
# Es UNA regla: la lee el modal (GET) y la vuelve a mirar el create de la dispensa antes de
# mandar. Que la pantalla mande `invitar_portal` no alcanza.
module PortalAcceso
  module InvitacionEnDispensa
    SIN_INSISTIR = 30.days

    module_function

    def para(paciente)
      ofrecer = ofrecer?(paciente)
      { ofrecer: ofrecer, marcada: ofrecer && !invitado_hace_poco?(paciente) }
    end

    def ofrecer?(paciente)
      paciente.club.portal_paciente_disponible? &&
        paciente.es_paciente? && paciente.aprobado? && paciente.email.present? &&
        !paciente.portal_activado? && paciente.link_portal_vigente.nil?
    end

    def invitado_hace_poco?(paciente)
      paciente.accesos_portal.where(motivo: 'invitacion').where('created_at > ?', SIN_INSISTIR.ago).exists?
    end

    # La manda si corresponde y dice qué pasó, para el aviso de la pantalla. Nunca hace fallar a la
    # dispensa: el producto ya salió y la plata ya entró.
    def mandar_si_corresponde(paciente, por:)
      return nil unless ofrecer?(paciente)

      resultado = Invitar.call(paciente, creado_por: por)
      { mail_enviado: resultado.ok? && resultado.mail_enviado }
    rescue StandardError => e
      Rails.logger.warn("[portal] no se pudo invitar en la dispensa al paciente #{paciente.id}: #{e.class} #{e.message}")
      { mail_enviado: false }
    end
  end
end
