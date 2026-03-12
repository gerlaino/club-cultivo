class Socio < ApplicationRecord
  acts_as_paranoid
  belongs_to :club
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :deleted_by, class_name: "User", optional: true

  has_many :notas, class_name: "SocioNota", dependent: :destroy
  has_many :indicacion_medicas, dependent: :destroy
  has_many :dispensaciones, class_name: 'Dispensacion', dependent: :destroy

  # Active Storage para adjunto REPROCANN
  has_one_attached :reprocann_documento

  before_validation :normalize_dni!

  validates :nombre, :apellido, :dni, :dni_normalizado, :fecha_nacimiento, presence: true
  validates :dni_normalizado, uniqueness: true, format: { with: /\A\d{7,9}\z/, message: "debe tener 7 a 9 dígitos" }
  validate :fecha_nacimiento_pasada

  scope :for_club, ->(club_id) { where(club_id: club_id) }

  # Scope para vencimientos próximos
  scope :reprocann_por_vencer, -> {
    where('reprocann_vencimiento IS NOT NULL')
      .where('reprocann_vencimiento <= ?', 30.days.from_now)
      .where('reprocann_vencimiento >= ?', Date.today)
  }

  def nombre_completo
    "#{nombre} #{apellido}"
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