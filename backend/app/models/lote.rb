class Lote < ApplicationRecord

  belongs_to :club
  belongs_to :sala

  has_many :plants,                dependent: :destroy
  has_one  :costo_lote,            dependent: :destroy
  has_many :movimientos_contables, dependent: :nullify
  has_many :registros_ambientales, class_name: 'RegistroAmbiental', dependent: :destroy
  has_many :lote_eventos,          dependent: :destroy
  has_many_attached :fotos

  ESTADOS       = %w[semilla vegetativo floracion cosecha curado finalizado].freeze
  TIPOS_CULTIVO = %w[sustrato hidroponia aeroponia].freeze
  TIPOS_LUZ     = %w[led hps cmh natural mixta].freeze
  SUSTRATOS     = %w[tierra coco perlita mezcla rockwool fibra_coco].freeze
  FOTOPERIODOS  = %w[20/4 18/6 16/8 12/12 auto].freeze

  validates :codigo,            uniqueness: { scope: :club_id }
  validates :estado,            inclusion: { in: ESTADOS }, allow_blank: false
  validates :plants_count,      numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :grow_type,         inclusion: { in: TIPOS_CULTIVO }, allow_blank: true
  validates :light_type,        inclusion: { in: TIPOS_LUZ },     allow_blank: true
  validates :tamanio_maceta,    numericality: { greater_than: 0 }, allow_nil: true
  validates :semanas_floracion, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :start_date,        presence: true

  before_create :generar_codigo

  scope :activos,     -> { where(estado: %w[vegetativo floracion]) }
  scope :finalizados, -> { where(estado: 'finalizado') }
  scope :por_sala,    ->(sala_id) { where(sala_id: sala_id) }
  scope :recientes,   -> { order(created_at: :desc) }

  def dias_desde_inicio
    return 0 unless start_date
    (Date.today - start_date).to_i
  end

  def progreso_ciclo
    case estado
    when 'semilla'    then 0
    when 'vegetativo' then 20
    when 'floracion'  then 55
    when 'cosecha'    then 80
    when 'curado'     then 95
    when 'finalizado' then 100
    else 0
    end
  end
  end
