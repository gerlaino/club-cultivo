module Pacientes
  # La cuenta del paciente para SU portal.
  #
  # Desde el 27-oct-2026 entra con su DNI y una clave que elige él desde un link
  # (`PortalAcceso::Invitar`): nadie de la organización la conoce. La cuenta igual necesita un
  # `email` único (Devise): se le arma `nombre.apellido@organizacion.paciente`, que no es una
  # casilla y no recibe nada. Es el identificador de las cuentas de antes, que pueden seguir
  # entrando con él por el login de siempre.
  #
  # La clave inicial la genera `User.password_temporal`, distinta para cada uno, y NO se muestra
  # ni se manda: hasta que abre el link, la cuenta no tiene una clave que alguien sepa.
  class Acceso
    Resultado = Struct.new(:user, :password_inicial, :error, :mail, keyword_init: true) do
      def ok? = error.nil?
    end

    def self.crear!(paciente) = new(paciente).crear!

    def initialize(paciente)
      @paciente = paciente
      @club     = paciente.club
    end

    # Idempotente: si ya tiene cuenta no se toca ni se le cambia la clave. Que un alta reintentada
    # le rote la contraseña al paciente que ya la tenía anotada es peor que no hacer nada.
    def crear!
      return Resultado.new(user: @paciente.user) if @paciente.user_id.present?

      password = User.password_temporal
      user = User.new(
        email:      email_disponible,
        first_name: @paciente.nombre.to_s.strip.presence || 'Paciente',
        last_name:  @paciente.apellido.to_s.strip,
        role:       'paciente',
        club_id:    @club.id,
        password:   password,
        password_confirmation: password
      )

      return Resultado.new(error: user.errors.full_messages.to_sentence) unless user.save

      @paciente.update_column(:user_id, user.id)
      Resultado.new(user: user, password_inicial: password)
    end

    # `nombre.apellido@organizacion.paciente`. Sin tildes ni espacios: se dicta por teléfono.
    #
    # Los dos lados se normalizan distinto y por eso van separados: la persona lleva PUNTO entre
    # nombre y apellido, y la organización guiones. Con un solo normalizador el dominio quedaba
    # "mi organizacion.paciente" —con un espacio adentro— y Devise lo rechazaba entero.
    def self.email_base(paciente, club)
      persona = [paciente.nombre, paciente.apellido].compact_blank.join(' ')
      persona = 'paciente' if persona.blank?

      "#{persona.parameterize(separator: ' ').squeeze(' ').strip.tr(' ', '.')}@#{club.name.parameterize}.paciente"
    end

    private

    # El mail de usuario es único en TODA la base, no por organización: dos Juan Pérez en dos
    # clubes distintos ya se separan por el nombre de la organización, y dos en el mismo se
    # separan con un número. Sin esto el segundo homónimo no se podía dar de alta.
    def email_disponible
      base = self.class.email_base(@paciente, @club)
      return base unless User.unscoped.exists?(email: base)

      usuario, dominio = base.split('@', 2)
      (2..).each do |n|
        candidato = "#{usuario}#{n}@#{dominio}"
        return candidato unless User.unscoped.exists?(email: candidato)
      end
    end
  end
end
