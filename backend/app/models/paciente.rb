class Paciente < ApplicationRecord
  acts_as_paranoid
  belongs_to :club
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :deleted_by, class_name: "User", optional: true

  has_many :notas, class_name: "PacienteNota", dependent: :destroy
  has_many :indicacion_medicas, dependent: :destroy
  has_many :dispensaciones, class_name: 'Dispensacion', dependent: :destroy
  has_many :patient_documents, dependent: :destroy
  has_one  :cuenta_corriente, dependent: :destroy

  has_one_attached :reprocann_documento

  before_validation :normalize_dni!

  validates :nombre, :apellido, :dni, :dni_normalizado, :fecha_nacimiento, presence: true
  validates :dni_normalizado, uniqueness: true, format: { with: /\A\d{7,9}\z/, message: "debe tener 7 a 9 dígitos" }
  validate :fecha_nacimiento_pasada

  scope :for_club,          ->(club_id) { where(club_id: club_id) }
  scope :con_seguimiento,   -> { where(con_seguimiento_medico: true) }
  scope :sin_seguimiento,   -> { where(con_seguimiento_medico: false) }

  scope :reprocann_por_vencer, -> {
    where('reprocann_vencimiento IS NOT NULL')
      .where('reprocann_vencimiento <= ?', 30.days.from_now)
      .where('reprocann_vencimiento >= ?', Date.today)
  }

  def nombre_completo
    "#{nombre} #{apellido}"
  end

  def saldo_cc
    cuenta_corriente&.saldo_disponible&.to_f
  end

  def limite_cc
    cuenta_corriente&.limite_credito&.to_f
  end

  def dispensado_mes_actual_g
    dispensaciones.del_mes.sum(:cantidad).to_f
  end

  def porcentaje_limite_mensual
    return nil unless limite_dispensacion_mensual_g.present? && limite_dispensacion_mensual_g > 0
    [(dispensado_mes_actual_g / limite_dispensacion_mensual_g.to_f * 100).round(1), 100].min
  end

  private

  def normalize_dni!
    return if dni.blank?
    self.dni_normalizado = dni.gsub(/\D/, "")
  end

  def fecha_nacimiento_pasada
    if fecha_nacimiento.present? && fecha_nacimiento >= Date.today
      errors.add(:fecha_nacimiento, "debe ser una fecha pasada")
    end
  end
end
