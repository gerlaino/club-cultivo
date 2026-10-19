# LO QUE LOS TURNOS DICEN DE UN PACIENTE (19-oct-2026). Antes `Pacientes::Entrevista` sacaba de acá
# el «pendiente de entrevista»; ya no: pendiente de entrevista es un paso del REPROCANN
# (`Pacientes::Situacion`). Los turnos agregan tres datos chicos al lado:
#
# · proximo_turno_at: su próximo turno dado (programado o confirmado, de ahora en adelante).
# · falto_turno_el:   su último turno quedó «ausente» y no tiene otro dado después → la fecha.
#                     Ahí hay que volver a darle turno.
# · turno_sin_cerrar: tiene un turno cuya hora ya pasó y el médico no lo cerró. Es un aviso para
#                     el médico y administración, no un estado del paciente.
#
# Una sola tanda de consultas para una lista entera. Con `medico_id`, sólo los turnos de ese médico.
module Pacientes
  module Agenda
    ESTADOS_ABIERTOS = %w[programado confirmado].freeze

    def self.para(paciente_ids, medico_id: nil, ahora: Time.current)
      ids = Array(paciente_ids).compact
      return {} if ids.empty?

      turnos = Turno.where(paciente_id: ids, deleted_at: nil)
      turnos = turnos.where(medico_id: medico_id) if medico_id
      abiertos = turnos.where(estado: ESTADOS_ABIERTOS)

      sin_cerrar = abiertos.where('fecha_hora < ?', ahora).distinct.pluck(:paciente_id).to_set
      proximos   = abiertos.where('fecha_hora >= ?', ahora).group(:paciente_id).minimum(:fecha_hora)

      # El último turno no cancelado de cada paciente; si es «ausente», faltó (y desde cuándo).
      ultimos = turnos.where.not(estado: 'cancelado')
                      .select('DISTINCT ON (paciente_id) paciente_id, estado, fecha_hora')
                      .order(:paciente_id, fecha_hora: :desc)
      faltas = ultimos.to_a.select { |t| t.estado == 'ausente' }
                      .to_h { |t| [t.paciente_id, t.fecha_hora.in_time_zone.to_date] }

      (sin_cerrar.to_a | proximos.keys | faltas.keys).index_with do |id|
        { proximo_turno_at: proximos[id], falto_turno_el: faltas[id], turno_sin_cerrar: sin_cerrar.include?(id) }
      end
    end

    # Cuántos turnos ya pasaron sin cerrar, por médico (el contador «Dra. López: 3 sin atender»).
    def self.sin_cerrar_por_medico(club, ahora: Time.current)
      club.turnos.where(deleted_at: nil, estado: ESTADOS_ABIERTOS).where('fecha_hora < ?', ahora)
          .group(:medico_id).count
    end
  end
end
