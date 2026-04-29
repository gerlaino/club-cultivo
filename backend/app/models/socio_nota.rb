class SocioNota < ApplicationRecord
  self.table_name = 'paciente_notas'
  acts_as_paranoid

  belongs_to :paciente, foreign_key: :paciente_id

  validates :contenido, presence: true

  scope :for_club, ->(club_id) { where(club_id: club_id) }
end
