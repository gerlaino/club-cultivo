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
  TAREAS    = %w[riego nutricion poda defoliacion scrog_lst revision_plagas limpieza_sala ajuste_luz registro_ambiental].freeze

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

  before_save  :calcular_vpd
  after_save   :propagar_a_lecturas_ambientales

  scope :recientes, -> { order(registrado_en: :desc) }
  scope :del_lote,  ->(lote_id) { where(lote_id: lote_id) }

  COLUMNAS_AMBIENTALES = {
    temperatura:          'temperatura',
    humedad:              'humedad',
    vpd:                  'vpd',
    co2:                  'co2',
    ppfd:                 'ppfd',
    ph:                   'ph',
    ec:                   'ec',
    ph_runoff:            'ph_runoff',
    ec_runoff:            'ec_runoff',
    temperatura_sustrato: 'temperatura_sustrato',
  }.freeze

  private

  def propagar_a_lecturas_ambientales
    sala_id = lote.sala_id
    return unless sala_id.present?

    propagadas = 0
    COLUMNAS_AMBIENTALES.each do |col, tipo|
      valor = public_send(col)
      next if valor.nil?

      lectura = LecturaAmbiental.find_or_initialize_by(
        origen_record_type: 'RegistroAmbiental',
        origen_record_id:   id,
        tipo:               tipo
      )
      lectura.assign_attributes(
        club_id:   club_id,
        sala_id:   sala_id,
        lote_id:   lote_id,
        valor:     valor,
        unidad:    AmbienteTipos::TIPOS_CANONICOS[tipo],
        fuente:    'manual',
        medido_at: registrado_en
      )
      lectura.save!
      propagadas += 1
    end

    begin
      EvaluarReglasJob.perform_later(sala_id) if propagadas > 0
    rescue => e
      Rails.logger.warn "EvaluarReglasJob enqueue failed: #{e.message}"
    end
  end

  def calcular_vpd
    return unless temperatura.present? && humedad.present?
    t   = temperatura.to_f
    hr  = humedad.to_f
    svp = 0.6108 * Math.exp(17.27 * t / (t + 237.3))
    self.vpd = (svp * (1 - hr / 100.0)).round(3)
  end
end