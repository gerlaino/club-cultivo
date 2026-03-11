class Evento < ApplicationRecord
  belongs_to :club

  # Active Storage para imágenes
  has_many_attached :imagenes

  # Validaciones
  validates :titulo, presence: true
  validates :fecha_inicio, presence: true
  validate :fecha_fin_debe_ser_posterior

  # Scopes
  scope :activos, -> { where(activo: true) }
  scope :proximos, -> { where('fecha_inicio >= ?', Time.current) }
  scope :pasados, -> { where('fecha_inicio < ?', Time.current) }
  scope :ordenados, -> { order(fecha_inicio: :asc) }
  scope :para_web, -> { activos.proximos.ordenados }

  private

  def fecha_fin_debe_ser_posterior
    if fecha_fin.present? && fecha_inicio.present? && fecha_fin < fecha_inicio
      errors.add(:fecha_fin, "debe ser posterior a la fecha de inicio")
    end
  end
end