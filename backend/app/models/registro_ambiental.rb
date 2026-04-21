class RegistroAmbiental < ApplicationRecord
  self.table_name = 'registros_ambientales'

  belongs_to :lote
  belongs_to :user
  belongs_to :club

  has_one_attached :archivo_csv

  ESTADOS   = %w[excelente bueno regular malo critico].freeze
  ESPECTROS = %w[veg bloom auto mixto].freeze
  FASES     = %w[crecimiento floracion engorde lavado].freeze
  FUENTES   = %w[manual csv_bluelab sensor_mqtt asistente_voz].freeze
  PLAGAS    = %w[ninguna leve moderada severa].freeze

  validates :registrado_en,  presence: true
  validates :estado_general, inclusion: { in: ESTADOS }, allow_blank: true
  validates :fuente,         inclusion: { in: FUENTES }, allow_blank: true
  validates :temperatura,    numericality: { greater_than: 0, less_than: 60 }, allow_nil: true
  validates :temperatura_sustrato, numericality: { greater_than: 0, less_than: 60 }, allow_nil: true
  validates :humedad,        numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :ph,             numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 14 }, allow_nil: true
  validates :ph_runoff,      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 14 }, allow_nil: true
  validates :co2,            numericality: { greater_than: 0 }, allow_nil: true
  validates :horas_luz,      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }, allow_nil: true
  validates :ppfd,           numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_save :calcular_vpd

  scope :recientes, -> { order(registrado_en: :desc) }
  scope :del_lote,  ->(lote_id) { where(lote_id: lote_id) }

  private

  def calcular_vpd
    return unless temperatura.present? && humedad.present?
    t   = temperatura.to_f
    hr  = humedad.to_f
    svp = 0.6108 * Math.exp(17.27 * t / (t + 237.3))
    self.vpd = (svp * (1 - hr / 100.0)).round(3)
  end
end