class Sala < ApplicationRecord
  belongs_to :club
  belongs_to :created_by, class_name: "User", optional: true
  has_many :lotes, dependent: :destroy

  ESTADOS = %w[activa mantenimiento cerrada].freeze

  validates :nombre, presence: true, uniqueness: { scope: :club_id }
  validates :state, inclusion: { in: ESTADOS }, allow_blank: false
  validates :pots_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  enum state: { activa: "activa", mantenimiento: "mantenimiento", cerrada: "cerrada" }, _prefix: true

  scope :activas, -> { where(state: 'activa') }
  scope :en_mantenimiento, -> { where(state: 'mantenimiento') }

  # Total de plantas en esta sala (suma de todos sus lotes)
  def plantas_totales
    lotes.sum(:plants_count)
  end

  # Ocupación de la sala
  def porcentaje_ocupacion
    return 0 if pots_count.nil? || pots_count.zero?
    ((plantas_totales.to_f / pots_count) * 100).round(1)
  end

  def created_by_name
    created_by&.first_name || created_by&.email || "Sistema"
  end
end