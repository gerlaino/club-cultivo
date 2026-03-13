class Lote < ApplicationRecord
  belongs_to :club
  belongs_to :sala
  has_many :plants, dependent: :destroy

  ESTADOS = %w[planificacion vegetativo floracion secado cosechado finalizado].freeze
  TIPOS_CULTIVO = %w[sustrato hidroponia aeroponia].freeze
  TIPOS_LUZ = %w[led hps cmh natural mixta].freeze

  validates :codigo, presence: true, uniqueness: { scope: :club_id }
  validates :estado, inclusion: { in: ESTADOS }, allow_blank: false
  validates :plants_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :grow_type, inclusion: { in: TIPOS_CULTIVO }, allow_blank: true
  validates :light_type, inclusion: { in: TIPOS_LUZ }, allow_blank: true

  scope :activos, -> { where(estado: %w[vegetativo floracion secado]) }
  scope :finalizados, -> { where(estado: 'finalizado') }
  scope :por_sala, ->(sala_id) { where(sala_id: sala_id) }
  scope :recientes, -> { order(created_at: :desc) }

  # Días desde el inicio
  def dias_desde_inicio
    return 0 unless start_date
    (Date.today - start_date).to_i
  end

  # Estado del ciclo (para progress bar)
  def progreso_ciclo
    case estado
    when 'planificacion' then 0
    when 'vegetativo' then 25
    when 'floracion' then 60
    when 'secado' then 85
    when 'cosechado' then 95
    when 'finalizado' then 100
    else 0
    end
  end
end