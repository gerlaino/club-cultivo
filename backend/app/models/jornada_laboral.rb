class JornadaLaboral < ApplicationRecord
  self.table_name = 'jornadas_laborales'

  belongs_to :user
  belongs_to :club

  validates :fecha,        presence: true
  validates :hora_entrada, :hora_salida, presence: true, format: { with: /\A\d{2}:\d{2}\z/, message: 'formato HH:MM' }
  validate  :salida_despues_de_entrada
  validate  :fecha_no_futura

  scope :del_mes, ->(anio, mes) {
    ini = Date.new(anio, mes, 1)
    where(fecha: ini..ini.end_of_month)
  }
  scope :recientes, -> { order(fecha: :desc) }

  # Horas trabajadas (decimal). Soporta turno que cruza medianoche.
  def horas
    e = minutos(hora_entrada)
    s = minutos(hora_salida)
    return 0 if e.nil? || s.nil?
    diff = s - e
    diff += 24 * 60 if diff < 0
    (diff / 60.0).round(2)
  end

  private

  def minutos(hhmm)
    return nil unless hhmm.to_s =~ /\A(\d{2}):(\d{2})\z/
    $1.to_i * 60 + $2.to_i
  end

  def salida_despues_de_entrada
    return if hora_entrada.blank? || hora_salida.blank?
    return if minutos(hora_entrada) && minutos(hora_salida) && hora_entrada != hora_salida
    errors.add(:hora_salida, 'debe ser distinta a la entrada')
  end

  def fecha_no_futura
    errors.add(:fecha, 'no puede ser futura') if fecha.present? && fecha > Date.current
  end
end
