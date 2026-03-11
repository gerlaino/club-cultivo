class Genetica < ApplicationRecord
  belongs_to :club

  # Active Storage para fotos
  has_many_attached :fotos

  # Validaciones
  validates :nombre, presence: true
  validates :thc, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :cbd, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :tipo, inclusion: { in: %w[indica sativa hibrida], allow_nil: true }

  # Scopes
  scope :activas, -> { where(activa: true) }
  scope :disponibles, -> { where(disponible: true) }
  scope :para_web, -> { activas.disponibles }

  # Orden por defecto
  default_scope { order(nombre: :asc) }
end