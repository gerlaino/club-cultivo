module Pacientes
  # La cuenta con la que el paciente entra a SU portal.
  #
  # Un paciente no tiene por qué tener mail —muchos dan de alta sin uno, y el que dan es el de un
  # familiar— así que la cuenta no se apoya en su correo: se le arma un usuario propio con la
  # forma `nombre.apellido@organizacion.paciente`. No es una casilla real y no recibe nada; es un
  # identificador para entrar, y por eso se puede dictar por teléfono sin que nadie tipee mal un
  # dominio.
  #
  # La contraseña la genera `User.password_temporal` y es DISTINTA para cada uno. Una clave fija
  # sería fatal acá y peor que en el equipo: el usuario se deriva del nombre, así que cualquiera
  # que conozca a un paciente de la organización lo deduce, y con una clave común entraría a su
  # historia clínica y a sus dispensaciones. La cambia el paciente desde su perfil; el usuario no.
  class Acceso
    Resultado = Struct.new(:user, :password_inicial, :error, keyword_init: true) do
      def ok? = error.nil?
    end

    def self.crear!(paciente) = new(paciente).crear!

    # Le da una contraseña nueva a quien ya tiene cuenta. Es la única forma de recuperarla: la
    # inicial se muestra una vez y no se guarda en claro en ningún lado.
    def self.restablecer!(paciente) = new(paciente).restablecer!

    # Cómo se vería su usuario si se le creara la cuenta. Sirve para mostrarlo ANTES de crearla,
    # así quien la crea sabe qué le va a quedar.
    def self.previsualizar(paciente) = email_base(paciente, paciente.club)

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

    def restablecer!
      user = @paciente.user
      return Resultado.new(error: 'Este paciente todavía no tiene cuenta.') if user.nil?

      password = User.password_temporal
      user.update!(password: password, password_confirmation: password)
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
