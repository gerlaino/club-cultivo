class DisponibilidadMedico < ApplicationRecord
  belongs_to :medico, class_name: 'User'
  belongs_to :club

  DIAS = %w[lunes martes miercoles jueves viernes sabado domingo].freeze

  validates :dia_semana,  inclusion: { in: 0..6 }
  validates :hora_inicio, numericality: { greater_than_or_equal_to: 0, less_than: 1440 }
  validates :hora_fin,    numericality: { greater_than: 0, less_than_or_equal_to: 1440 }
  validate  :fin_despues_de_inicio

  scope :activas, -> { where(activa: true) }
  scope :del_medico, ->(user_id) { where(medico_id: user_id) }

  def hora_inicio_s
    "%02d:%02d" % [hora_inicio / 60, hora_inicio % 60]
  end

  def hora_fin_s
    "%02d:%02d" % [hora_fin / 60, hora_fin % 60]
  end

  private

  def fin_despues_de_inicio
    return unless hora_inicio && hora_fin
    errors.add(:hora_fin, 'debe ser posterior al inicio') if hora_fin <= hora_inicio
  end
end
