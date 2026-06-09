class Turno < ApplicationRecord
  belongs_to :paciente
  belongs_to :medico, class_name: 'User'
  belongs_to :club

  TIPOS   = %w[primera_vez seguimiento revision urgencia].freeze
  ESTADOS = %w[programado confirmado realizado cancelado ausente].freeze

  validates :fecha_hora, presence: true
  validates :tipo,   inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }

  scope :proximos,   -> { where('fecha_hora >= ?', Time.current).order(:fecha_hora) }
  scope :pasados,    -> { where('fecha_hora < ?',  Time.current).order(fecha_hora: :desc) }
  scope :del_medico, ->(user_id) { where(medico_id: user_id) }
end
