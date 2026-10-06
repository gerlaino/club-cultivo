# «PENDIENTE DE ENTREVISTA» y «FALTÓ AL TURNO» (Germán, 6-oct-2026). No se marcan a mano: salen de
# los turnos, como «suspendido» sale de los retiros.
#
# · Pendiente de entrevista: tiene un turno cuya hora YA PASÓ y el médico no lo cerró (sigue
#   programado o confirmado). Es lo que administración usa para apurar al médico. Deja de estarlo
#   el día que el médico lo marca realizado (o ausente, o lo cancela).
# · Faltó al turno: su último turno quedó «ausente» y no tiene otro dado después. Ahí no hay que
#   apurar al médico sino volver a darle turno al paciente: por eso va aparte.
#
# Una sola consulta para una lista entera de pacientes (la lista de pacientes y la del médico la
# piden para cada fila): devuelve { paciente_id => 'pendiente_entrevista' | 'falto_turno' }; el
# que no está en el hash no tiene nada pendiente. Con `medico_id`, sólo cuenta los turnos de ese médico.
module Pacientes
  module Entrevista
    ESTADOS_ABIERTOS = %w[programado confirmado].freeze

    def self.para(paciente_ids, medico_id: nil, ahora: Time.current)
      ids = Array(paciente_ids).compact
      return {} if ids.empty?

      turnos = Turno.where(paciente_id: ids, deleted_at: nil)
      turnos = turnos.where(medico_id: medico_id) if medico_id

      pendientes = turnos.where(estado: ESTADOS_ABIERTOS).where('fecha_hora < ?', ahora)
                         .distinct.pluck(:paciente_id)

      # El último turno no cancelado de cada paciente; si es «ausente», faltó.
      ultimos = turnos.where.not(estado: 'cancelado')
                      .select('DISTINCT ON (paciente_id) paciente_id, estado')
                      .order(:paciente_id, fecha_hora: :desc)
      faltaron = ultimos.to_a.select { |t| t.estado == 'ausente' }.map(&:paciente_id)

      resultado = faltaron.index_with { 'falto_turno' }
      pendientes.each { |id| resultado[id] = 'pendiente_entrevista' } # pendiente gana: hay que apurar
      resultado
    end

    # Cuántos turnos ya pasaron sin cerrar, por médico (el contador «Dra. López: 3 sin atender»).
    def self.sin_cerrar_por_medico(club, ahora: Time.current)
      club.turnos.where(deleted_at: nil, estado: ESTADOS_ABIERTOS).where('fecha_hora < ?', ahora)
          .group(:medico_id).count
    end
  end
end
