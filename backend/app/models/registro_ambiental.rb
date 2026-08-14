class RegistroAmbiental < ApplicationRecord
  self.table_name = 'registros_ambientales'

  belongs_to :lote
  belongs_to :user
  belongs_to :club
  acts_as_tenant(:club)

  has_one_attached :archivo_csv

  # Dónde se tomó la medición. Un lote enraizando vive dentro del propagador, que tiene su
  # propio clima: 28 °C y 90 % adentro de la incubadora es el objetivo, y en el cuarto sería
  # una emergencia. Sin distinguirlos, el KPI de la sala mostraba el aire de la incubadora.
  PUNTOS_MEDICION = %w[sala incubadora].freeze

  ESTADOS   = %w[excelente bueno regular malo critico].freeze
  ESPECTROS = %w[veg bloom auto mixto].freeze
  FASES     = %w[crecimiento floracion engorde lavado].freeze
  FUENTES   = %w[manual csv_bluelab sensor_mqtt asistente_voz].freeze
  # Producto enraizante, ESTRUCTURADO: distintos geles/polvos tienen tasas de prendimiento
  # distintas, y así se puede cruzar con el % de prendimiento que ya medimos.
  ENRAIZANTES = %w[gel polvo liquido miel_canela ninguno otro].freeze
  PLAGAS    = %w[ninguna leve moderada severa].freeze
  TAREAS    = %w[riego nutricion poda defoliacion scrog_lst revision_plagas limpieza_sala ajuste_luz registro_ambiental].freeze

  validates :registrado_en,  presence: true
  validates :punto_medicion, inclusion: { in: PUNTOS_MEDICION }
  validates :estado_general, inclusion: { in: ESTADOS }, allow_blank: true
  validates :fuente,         inclusion: { in: FUENTES }, allow_blank: true
  validates :producto_enraizante, inclusion: { in: ENRAIZANTES }, allow_blank: true
  validates :temperatura,    numericality: { greater_than: 0, less_than: 60 }, allow_nil: true
  validates :temperatura_sustrato, numericality: { greater_than: 0, less_than: 60 }, allow_nil: true
  validates :humedad,        numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :ph,             numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 14 }, allow_nil: true
  validates :ph_runoff,      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 14 }, allow_nil: true
  validates :co2,            numericality: { greater_than: 0 }, allow_nil: true
  validates :horas_luz,      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }, allow_nil: true
  validates :ppfd,           numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :punto_segun_estado_del_lote, on: :create
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

  # Un lote ENRAIZANDO vive adentro del propagador: su ambiente es el del domo, no el del cuarto.
  # No es una preferencia de quien carga el dato, es dónde está físicamente la planta — por eso se
  # deriva acá y no se pide en cada formulario. `registrar_sala` ya excluye a los enraizando por la
  # misma razón; esto cierra las otras puertas (el registro de UN lote, el asistente por voz, seeds).
  #
  # Al avanzar de fase el lote sale del domo, pero sus registros viejos conservan el punto que
  # tenían: son historia de dónde se midió, no del estado actual.
  def punto_segun_estado_del_lote
    self.punto_medicion = lote&.estado == 'enraizado' ? 'incubadora' : 'sala'
  end

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
        club_id:        club_id,
        sala_id:        sala_id,
        lote_id:        lote_id,
        valor:          valor,
        unidad:         AmbienteTipos::TIPOS_CANONICOS[tipo],
        fuente:         'manual',
        # Viaja con la lectura: sin esto el punto se pierde en la propagación, que es donde el
        # dato deja de estar atado al lote y pasa a ser "el ambiente de la sala".
        punto_medicion: punto_medicion,
        medido_at:      registrado_en
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