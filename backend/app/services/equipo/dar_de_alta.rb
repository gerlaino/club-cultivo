module Equipo
  # El alta de una persona del equipo de una organización. Una sola puerta desde el 12-oct-2026:
  # la hace la plataforma (super admin); el admin la pide (`Equipo::PedirUsuario`).
  #
  # Las reglas son las que antes vivían en el alta del admin y siguen valiendo:
  #   · el rol tiene que servirle a lo que la organización contrató (`roles_para_alta`): un
  #     repartidor sin Delivery entraría a una app sin pantallas;
  #   · sin sede no hay operativos (loguearían a una app vacía); el admin sí;
  #   · la contraseña inicial se genera acá, distinta para cada uno, y se le manda el link para
  #     elegir la suya si tiene mail real.
  # Lo que cambió: el cupo del plan AVISA y no bloquea. Super admin puede pasarse confirmándolo
  # (`exceder_cupo: true`): eso se cobra aparte, y el excedente queda a la vista
  # (`PlanEnforcer#excedentes_de_usuarios`). En autocultivo no hay equipo: eso sí no se pasa.
  class DarDeAlta
    class Error < StandardError
      attr_reader :status, :extra
      def initialize(msg, status: :unprocessable_entity, extra: {})
        super(msg)
        @status = status
        @extra  = extra
      end
    end

    Resultado = Struct.new(:user, :password_inicial, :mail_enviado, :excede_cupo, keyword_init: true)

    def initialize(club:, atributos:, exceder_cupo: false, password: nil)
      @club  = club
      @attrs = atributos.to_h.symbolize_keys
      @rol   = @attrs[:role].to_s
      @exceder_cupo = exceder_cupo
      @password = password.presence
    end

    def call
      excede = validar_cupo! # primero: en autocultivo el «no» es que no hay equipo, no el rol
      validar_rol!
      if @rol != 'admin' && !@club.sedes.exists?
        raise Error, 'La organización no tiene ninguna sede: creá una antes de dar de alta usuarios operativos.'
      end

      # Sin contraseña escrita por super admin, se genera una temporal y dictable (antes caía una
      # FIJA para toda la plataforma).
      password = @password || User.password_temporal
      user = @club.users.build(@attrs.slice(:email, :email_personal, :first_name, :last_name, :role))
      user.password = user.password_confirmation = password
      raise Error, user.errors.full_messages.to_sentence unless user.save

      Resultado.new(user: user, password_inicial: password, excede_cupo: excede,
                    mail_enviado: Acceso::EnviarRestablecimiento.call(user))
    end

    private

    # Los mismos roles que se ofrecían en Equipo (`Club::ROLES_ALTA_CLUB`): supervisor está
    # suspendido para altas nuevas y abogado/auditor no se ofrecen, también desde la plataforma.
    def validar_rol!
      return if @club.roles_para_alta.include?(@rol)

      faltante = @club.modulo_faltante_para_rol(@rol)
      label = Club::ROLES_META.dig(@rol, :label) || @rol.presence || '(vacío)'
      raise Error, (faltante ? "#{label} necesita el módulo #{Club.label_modulo(faltante)}, que esta organización no tiene activo." :
                               "El rol #{label} no se puede asignar en esta organización.")
    end

    # true si el alta queda por encima del plan (confirmada).
    def validar_cupo!
      enforcer = PlanEnforcer.new(@club)
      return false if enforcer.puede_crear_usuario?(@rol)

      tope = enforcer.tope_por_rol
      if tope.nil? || !enforcer.equipo?
        raise Error.new(PlanEnforcer.error_limite_rol(@rol, plan: enforcer.info[:label], tope: nil)[:mensaje],
                        status: :payment_required)
      end
      return true if @exceder_cupo

      label = Club::ROLES_META.dig(@rol, :label) || @rol
      raise Error.new("Pasa el cupo del plan: ya tiene #{enforcer.usuarios_de_rol(@rol)} de #{tope} (#{label}). " \
                      'Si lo das de alta igual, queda por encima del plan para cobrarlo aparte.',
                      status: :conflict, extra: { excede_cupo: true, rol: @rol, tope: tope,
                                                  actuales: enforcer.usuarios_de_rol(@rol) })
    end
  end
end
