# CAMBIAR EL ROL DE UN USUARIO PASA POR LAS MISMAS PUERTAS QUE CREARLO (sep-2026, revisión de
# Germán: «si editamos el rol, ¿qué pasa?»).
#
# El rol se puede cambiar —los permisos cambian en el acto porque se leen del usuario en cada
# request, y el historial queda: dispensas, turnos, cobros y auditoría cuelgan del `user_id`, y
# la auditoría del usuario deja quién lo cambió, cuándo y de qué a qué (`auditar_solo :role`)—.
# Lo que estaba mal es que `update` aceptaba CUALQUIER rol sin mirar nada: se podía pasar a uno
# que no se ofrece (supervisor, auditor, abogado, suspendidos por ahora), a uno cuyo módulo la
# organización no tiene (y la persona no puede volver a entrar), o pisar el cupo del plan que el
# alta sí respeta. Y un repartidor con paquetes en la calle ya tenía su guard: queda.
#
# Devuelve `nil` si el cambio pasa, o `[status, payload]` para contestar.
module CambioDeRol
  extend ActiveSupport::Concern

  private

  def rechazo_cambio_de_rol(club, user, nuevo_rol)
    nuevo_rol = nuevo_rol.to_s
    return nil if nuevo_rol.blank? || nuevo_rol == user.role

    unless club.roles_para_alta.include?(nuevo_rol)
      faltante = club.modulo_faltante_para_rol(nuevo_rol)
      motivo = if faltante
                 "#{Club::ROLES_META.dig(nuevo_rol, :label) || nuevo_rol} necesita el módulo " \
                 "#{Club.label_modulo(faltante)}, que no está activo en esta organización."
               else
                 "El rol #{Club::ROLES_META.dig(nuevo_rol, :label) || nuevo_rol} no está disponible por ahora."
               end
      return [:unprocessable_entity, { errors: [motivo] }]
    end

    enforcer = PlanEnforcer.new(club)
    unless enforcer.puede_crear_usuario?(nuevo_rol)
      return [:payment_required, PlanEnforcer.error_limite_rol(nuevo_rol, plan: enforcer.info[:label],
                                                                tope: enforcer.usuarios_por_rol)]
    end

    if user.role == 'delivery'
      pend = Dispensacion.joins(stock: :sede).where(sedes: { club_id: club.id })
                         .where(delivery_id: user.id, con_envio: true, estado_envio: %w[pendiente en_viaje]).count
      if pend.positive?
        return [:unprocessable_entity, { errors: ["#{user.first_name} tiene #{pend} despacho#{'s' if pend != 1} pendiente#{'s' if pend != 1} asignado#{'s' if pend != 1}. Reasignalos antes de cambiarle el rol."] }]
      end
    end

    nil
  end
end
