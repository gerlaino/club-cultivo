# backend/app/models/sala.rb
class Sala < ApplicationRecord
  belongs_to :club
  belongs_to :sede, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :lotes, dependent: :destroy
  has_many :sala_cultivadores, class_name: 'SalaCultivador', foreign_key: 'sala_id', dependent: :destroy
  has_many :cultivadores, through: :sala_cultivadores, source: :user
  has_many :notas, as: :noteable, dependent: :destroy

  ESTADOS = %w[activa mantenimiento cerrada].freeze
  KINDS   = %w[vegetativo floracion mixta madre clon manicura secado].freeze

  validates :nombre, presence: true, uniqueness: { scope: :club_id }
  validates :state,  inclusion: { in: ESTADOS }, allow_blank: false
  validate  :manicura_requiere_sede_produccion

  private

  def manicura_requiere_sede_produccion
    return unless kind == 'manicura'
    return if sede.nil?
    unless %w[produccion mixta].include?(sede.tipo)
      errors.add(:sede, 'La sala de manicura solo puede estar en sedes de producción o mixtas')
    end
  end

  public
  validates :pots_count,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :plants_max,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  enum state: { activa: "activa", mantenimiento: "mantenimiento", cerrada: "cerrada" }, _prefix: true

  scope :activas,        -> { where(state: 'activa') }
  scope :en_mantenimiento, -> { where(state: 'mantenimiento') }

  def plantas_totales
    lotes.sum(:plants_count)
  end

  def porcentaje_ocupacion
    return 0 unless tiene_limite_capacidad?
    [(plantas_totales.to_f / capacidad_maxima * 100).round(1), 100].min
  end

  def tiene_limite_capacidad?
    plants_max.to_i > 0 || pots_count.to_i > 0
  end

  def capacidad_maxima
    plants_max.to_i > 0 ? plants_max.to_i : pots_count.to_i
  end

  def capacidad_disponible
    return Float::INFINITY unless tiene_limite_capacidad?
    [capacidad_maxima - plantas_totales, 0].max
  end

  def created_by_name
    [created_by&.first_name, created_by&.last_name].compact.join(" ").presence || created_by&.email || "Sistema"
  end
end
