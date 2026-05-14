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
