class Lote < ApplicationRecord
  belongs_to :club
  belongs_to :sala
  has_many :plants, dependent: :destroy

  STATES = %w[activo finalizado cancelado].freeze

  validates :plants_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :grow_type, inclusion: { in: %w[sustrato hidroponia] }
  validates :state, inclusion: { in: STATES }, allow_nil: true

  scope :activos, -> { where(state: 'activo') }
  scope :finalizados, -> { where(state: 'finalizado') }
end