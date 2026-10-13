module Equipo
  # El admin de una organización PIDE un usuario; lo da de alta la plataforma desde super admin
  # (Germán, 12-oct-2026): el alta es el momento de vender, y el cupo del plan lo maneja quien
  # cobra. El pedido cae en la bandeja de Consultas de super admin (`SolicitudContacto`, tipo
  # `usuario`) con push a cada super admin, igual que una consulta de la página pública.
  #
  # El contacto del pedido es quien lo hace (para contestarle), no la persona a dar de alta: a ella
  # no se le manda nada hasta que exista su cuenta.
  class PedirUsuario
    class Error < StandardError; end

    def initialize(club:, por:, nombre: nil, apellido: nil, email: nil, rol: nil, nota: nil)
      @club = club
      @por  = por
      @persona = [nombre, apellido].map { |x| x.to_s.strip }.compact_blank.join(' ')
      @email = email.to_s.strip.downcase.presence
      @rol   = rol.to_s
      @nota  = nota.to_s.strip.presence
    end

    def call
      raise Error, 'Poné el nombre de la persona.' if @persona.blank?
      unless @club.roles_para_alta.include?(@rol)
        raise Error, "El rol #{Club::ROLES_META.dig(@rol, :label) || @rol.presence || '(vacío)'} no se puede pedir para esta organización."
      end
      if @email && !URI::MailTo::EMAIL_REGEXP.match?(@email)
        raise Error, 'El correo de la persona no es válido.'
      end

      solicitud = SolicitudContacto.create!(
        tipo: 'usuario', nombre: @por.nombre_completo.presence || @por.email,
        email: @por.email_real.presence || @por.email, organizacion: @club.name,
        mensaje: mensaje
      )
      avisar(solicitud)
      solicitud
    end

    private

    def mensaje
      enforcer = PlanEnforcer.new(@club)
      tope = enforcer.tope_por_rol
      actuales = enforcer.usuarios_de_rol(@rol)
      cupo = if PlanEnforcer::ROLES_SIN_TOPE.include?(@rol) || tope.nil? then 'sin tope'
             elsif actuales >= tope then "PASA EL CUPO: ya tiene #{actuales} de #{tope}"
             else "dentro del cupo (#{actuales} de #{tope})"
             end
      [
        "Organización: #{@club.name} (##{@club.id})",
        "Persona: #{@persona}#{@email ? " <#{@email}>" : ''}",
        "Rol: #{Club::ROLES_META.dig(@rol, :label) || @rol} — #{cupo}",
        ("Nota: #{@nota}" if @nota),
      ].compact.join("\n")
    end

    def avisar(s)
      User.where(role: 'super_admin').find_each do |u|
        PushNotificationService.notify_user_async(u, tipo: 'consulta_nueva', title: 'Pedido de usuario',
                                                     body: "#{@club.name}: #{@persona}", url: '/super-admin/consultas')
      end
    rescue StandardError => e
      Rails.logger.warn("[pedir usuario] no se pudo avisar: #{e.message}")
    end
  end
end
