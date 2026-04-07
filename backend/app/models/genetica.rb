class Genetica < ApplicationRecord
  belongs_to :club
  has_many_attached :fotos

  validates :nombre, presence: true
  validates :thc, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :cbd, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :tipo, inclusion: { in: %w[indica sativa hibrida], allow_nil: true }

  scope :activas,      -> { where(activa: true) }
  scope :disponibles,  -> { where(disponible: true) }
  scope :visibles_web, -> { activas.where(visible_web: true) }

  default_scope { order(nombre: :asc) }
end