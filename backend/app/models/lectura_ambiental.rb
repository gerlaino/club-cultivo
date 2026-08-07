class LecturaAmbiental < ApplicationRecord
  self.table_name = 'lecturas_ambientales'

  include AmbienteTipos

  belongs_to :sala
  belongs_to :dispositivo, optional: true
  belongs_to :lote,        optional: true

  FUENTES = %w[manual webhook csv_import backfill].freeze

  validates :fuente,    inclusion: { in: FUENTES }
  validates :valor,     presence: true, numericality: true
  validates :unidad,    presence: true
  validates :medido_at, presence: true
  validate  :medido_at_en_rango_valido

  after_commit :calcular_vpd_automatico, on: [:create],
               if: -> { tipo.in?(%w[temperatura humedad]) && fuente != 'backfill' }
  after_commit :broadcast_lectura, on: [:create]

  scope :recientes,         -> { order(medido_at: :desc) }
  scope :del_tipo,          ->(t)       { where(tipo: t) }
  scope :de_sala,           ->(id)      { where(sala_id: id) }
  scope :en_rango,          ->(desde, hasta) { where(medido_at: desde..hasta) }
  scope :ultimas_n_minutos, ->(n)       { where('medido_at >= ?', n.minutes.ago) }
  scope :no_backfill,       ->          { where.not(fuente: 'backfill') }
  scope :para_timeseries,   ->(sala_id, tipo, desde, hasta) {
    de_sala(sala_id).del_tipo(tipo).en_rango(desde, hasta).order(medido_at: :asc)
  }

  class Diaria < ApplicationRecord
    self.table_name = 'lecturas_ambientales_diarias'
    belongs_to :sala
  end

  private

  def calcular_vpd_automatico
    otro_tipo = tipo == 'temperatura' ? 'humedad' : 'temperatura'
    otra = LecturaAmbiental
             .de_sala(sala_id)
             .del_tipo(otro_tipo)
             .where(medido_at: (medido_at - 5.minutes)..(medido_at + 5.minutes))
             .order(Arel.sql("ABS(EXTRACT(EPOCH FROM (medido_at - '#{medido_at}'::timestamptz)))"))
             .first
    return unless otra

    temp    = tipo == 'temperatura' ? valor.to_f : otra.valor.to_f
    hum     = tipo == 'humedad'     ? valor.to_f : otra.valor.to_f
    # El ajuste de hoja es POR SALA: bajo LED la hoja se enfría más que bajo HPS.
    offset  = sala&.leaf_temp_offset || Ambiente::VpdCalculator::OFFSET_HOJA_DEFAULT
    vpd_val = Ambiente::VpdCalculator.call(temperatura: temp, humedad: hum, offset_hoja: offset)

    LecturaAmbiental.find_or_initialize_by(
      sala_id:   sala_id,
      tipo:      'vpd',
      medido_at: medido_at
    ).tap do |l|
      l.club_id = club_id
      l.valor   = vpd_val
      l.unidad  = 'kPa'
      l.fuente  = 'manual'
      l.save!
    end
  rescue => e
    Rails.logger.warn "[VPD Auto] #{e.message}"
  end

  def broadcast_lectura
    ActionCable.server.broadcast("ambiente_sala_#{sala_id}", {
      tipo:      tipo,
      valor:     valor.to_f,
      unidad:    unidad,
      medido_at: medido_at.iso8601,
      sala_id:   sala_id,
    })
  rescue => e
    Rails.logger.warn "[AmbienteChannel] broadcast falló: #{e.message}"
  end

  def medido_at_en_rango_valido
    return if medido_at.nil?
    return if %w[manual backfill csv_import].include?(fuente)
    if medido_at > Time.current + 5.minutes
      errors.add(:medido_at, 'no puede ser una fecha futura')
    elsif medido_at < 7.days.ago
      errors.add(:medido_at, 'no puede tener más de 7 días de antigüedad')
    end
  end
end
