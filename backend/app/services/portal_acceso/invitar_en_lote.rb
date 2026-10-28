# Desde la lista de pacientes, administración elige a varios y les manda la invitación al portal
# por mail (27-oct-2026). Un mail por destinatario (`Invitar` de a uno: nunca `To:` múltiple ni
# BCC, que es dato de salud) y con el tope de 450 por día del correo.
#
# Los mails salen por la casilla de la organización si la conectó, y entonces el tope es el MISMO
# cupo del correo (`Correo::CupoDiario`: masivos, mails sueltos y links del portal). Si no la
# conectó salen por la de la plataforma y el tope cuenta sólo los links del portal de hoy. Si el
# lote no entra entero no se manda nada: mandar la mitad deja a administración sin saber a quién
# le llegó.
#
# Cada paciente que no se puede invitar vuelve con el motivo, en vez de fallar el lote entero.
module PortalAcceso
  class InvitarEnLote
    LIMITE_DIARIO = Correo::CupoDiario::LIMITE

    Resultado = Struct.new(:enviados, :omitidos, :error, keyword_init: true) do
      def ok? = error.nil?
    end

    def self.call(club:, paciente_ids:, por:) = new(club:, paciente_ids:, por:).call

    def self.restante(club)
      return Correo::CupoDiario.restante(club) if club.email_propio?

      [LIMITE_DIARIO - Correo::CupoDiario.portal_hoy(club), 0].max
    end

    def initialize(club:, paciente_ids:, por:)
      @club = club
      @ids  = Array(paciente_ids).map(&:to_i).uniq
      @por  = por
    end

    def call
      return Resultado.new(error: 'Tu organización no tiene el portal de pacientes abierto.') unless @club.portal_paciente_disponible?
      return Resultado.new(error: 'Elegí al menos un paciente.') if @ids.empty?

      # Sólo los de ESTA organización: un id de otra no se encuentra y vuelve como omitido.
      pacientes = @club.pacientes.where(id: @ids).index_by(&:id)
      omitidos  = []
      a_invitar = []
      @ids.each do |id|
        paciente = pacientes[id]
        motivo   = motivo_para_omitir(paciente)
        motivo ? omitidos << { id: id, nombre: paciente&.nombre_completo, motivo: motivo } : a_invitar << paciente
      end

      restante = self.class.restante(@club)
      if a_invitar.size > restante
        return Resultado.new(error: "Hoy quedan #{restante} envíos de #{LIMITE_DIARIO} y elegiste #{a_invitar.size}. " \
                                    'Elegí menos pacientes o mandá el resto mañana.')
      end

      enviados = 0
      a_invitar.each do |paciente|
        resultado = Invitar.call(paciente, creado_por: @por)
        if resultado.ok? && resultado.mail_enviado
          enviados += 1
        else
          omitidos << { id: paciente.id, nombre: paciente.nombre_completo, motivo: resultado.error || 'No se pudo mandar el mail.' }
        end
      end
      Resultado.new(enviados: enviados, omitidos: omitidos)
    end

    private

    def motivo_para_omitir(paciente)
      return 'No es un paciente de la organización.' if paciente.nil?
      return 'Está dado de baja.' unless paciente.es_paciente?
      return 'Todavía no está aprobado.' unless paciente.aprobado?
      return 'No tiene mail en la ficha.' if paciente.email.blank?
      return 'Ya entra a su portal.' if paciente.portal_activado?

      nil
    end
  end
end
