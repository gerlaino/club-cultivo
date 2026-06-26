class PacienteNota < ApplicationRecord
  include RestorableInterface
  self.table_name = 'paciente_notas'
  acts_as_paranoid

  belongs_to :paciente
  belongs_to :created_by, class_name: "User"
  belongs_to :deleted_by, class_name: "User", optional: true

  validates :contenido, presence: true

  scope :for_club, ->(club_id) { where(club_id: club_id) }
end
