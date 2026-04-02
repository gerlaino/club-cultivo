# backend/app/models/sala.rb
class Sala < ApplicationRecord
  belongs_to :club
  belongs_to :sede, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :lotes, dependent: :destroy
  has_many :sala_cultivadores, class_name: 'SalaCultivador', foreign_key: 'sala_id', dependent: :destroy
  has_many :cultivadores, through: :sala_cultivadores, source: :user

  ESTADOS = %w[activa mantenimiento cerrada].freeze
  KINDS   = %w[vegetativo floracion mixta madre clon].freeze

  validates :nombre,  presence: true, uniqueness: { scope: :club_id }
  validates :state,   inclusion: { in: ESTADOS }, allow_blank: false
  validates :pots_count,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :plants_max,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  enum state: { activa: "activa", mantenimiento: "mantenimiento", cerrada: "cerrada" }, _prefix: true

  scope :activas,        -> { where(state: 'activa') }
  scope :en_mantenimiento, -> { where(state: 'mantenimiento') }

  def plantas_totales
    lotes.sum(:plants_count)
  end

  def porcentaje_ocupacion
    max = plants_max.to_i > 0 ? plants_max : pots_count.to_i
    return 0 if max.zero?
    ((plantas_totales.to_f / max) * 100).round(1)
  end

  def capacidad_disponible
    max = plants_max.to_i > 0 ? plants_max : pots_count.to_i
    [max - plantas_totales, 0].max
  end

  def created_by_name
    created_by&.first_name || created_by&.email || "Sistema"
  end
end
