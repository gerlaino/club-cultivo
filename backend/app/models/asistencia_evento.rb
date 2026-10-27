# Un paciente que marcó «Asistiré» en un evento del portal (ver la migración `CrearAsistenciasEvento`).
class AsistenciaEvento < ApplicationRecord
  self.table_name = 'asistencias_evento'

  include Transmite
  transmite_como 'eventos'

  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :evento
  belongs_to :paciente

  validates :paciente_id, uniqueness: { scope: :evento_id }
end
