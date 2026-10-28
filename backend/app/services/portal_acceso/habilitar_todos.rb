# Al abrir el portal (contratarlo y prenderlo), TODO el padrón queda habilitado: a cada paciente
# activo y admitido que no tiene cuenta se le crea (`Pacientes::Acceso.crear!`). No se manda nada:
# la invitación le llega en su próxima dispensa o cuando administración la manda en lote.
#
# Con la cuenta creada, el que tiene mail ya puede entrar solo por «me olvidé la clave», que
# hasta hoy no le contestaba a los pacientes de antes del portal (no tenían cuenta).
#
# Idempotente: al que ya tiene cuenta no se lo toca. Corre en un job porque cada cuenta cifra
# una clave y un padrón de cientos no entra en un request.
module PortalAcceso
  class HabilitarTodos
    Resultado = Struct.new(:creadas, :errores, keyword_init: true)

    def self.call(club) = new(club).call

    def initialize(club)
      @club = club
    end

    def call
      return Resultado.new(creadas: 0, errores: []) unless @club.portal_paciente_disponible?

      creadas = 0
      errores = []
      ActsAsTenant.with_tenant(@club) do
        @club.pacientes.where(es_paciente: true, user_id: nil).where.not(aprobado_at: nil).find_each do |paciente|
          resultado = Pacientes::Acceso.crear!(paciente)
          resultado.ok? ? creadas += 1 : errores << { paciente_id: paciente.id, error: resultado.error }
        end
      end
      errores.each { |e| Rails.logger.warn("[portal] no se pudo crear la cuenta del paciente #{e[:paciente_id]}: #{e[:error]}") }
      Resultado.new(creadas: creadas, errores: errores)
    end
  end
end
