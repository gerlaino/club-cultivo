class Dispensacion < ApplicationRecord
  self.table_name = 'dispensaciones'

  belongs_to :socio
  belongs_to :user
  belongs_to :indicacion_medica, optional: true
  belongs_to :lote, optional: true

  has_one :movimiento_contable, dependent: :nullify
  belongs_to :sede, optional: true

  TIPOS_PRODUCTO = %w[flores aceite extracto crema].freeze

  validates :cantidad_gramos, presence: true, numericality: { greater_than: 0 }
  validates :tipo_producto, presence: true, inclusion: { in: TIPOS_PRODUCTO }
  validates :fecha_dispensacion, presence: true
  validate :fecha_no_futura
  validate :cupo_mensual_no_excedido, on: :create

  scope :del_mes, ->(fecha = Date.today) {
    where(fecha_dispensacion: fecha.beginning_of_month..fecha.end_of_month)
  }
  scope :del_socio, ->(socio_id) { where(socio_id: socio_id) }
  scope :recientes, -> { order(fecha_dispensacion: :desc, created_at: :desc) }

  # Cupo mensual por socio (en gramos) - puede ser configurable por club
  CUPO_MENSUAL_GRAMOS = 40.0

  def self.total_dispensado_mes(socio_id, mes = Date.today)
    del_mes(mes).del_socio(socio_id).sum(:cantidad_gramos)
  end

  def self.cupo_disponible(socio_id, mes = Date.today)
    total = total_dispensado_mes(socio_id, mes)
    CUPO_MENSUAL_GRAMOS - total
  end

  def cupo_disponible_tras_dispensacion
    mes = fecha_dispensacion || Date.today
    total_mes = self.class.total_dispensado_mes(socio_id, mes)
    self.class::CUPO_MENSUAL_GRAMOS - total_mes - cantidad_gramos.to_f
  end

  private

  def fecha_no_futura
    if fecha_dispensacion.present? && fecha_dispensacion > Date.today
      errors.add(:fecha_dispensacion, "no puede ser futura")
    end
  end

  def cupo_mensual_no_excedido
    return unless socio_id && cantidad_gramos && fecha_dispensacion

    disponible = cupo_disponible_tras_dispensacion

    if disponible < 0
      errors.add(:cantidad_gramos, "excede el cupo mensual disponible (#{self.class.cupo_disponible(socio_id, fecha_dispensacion).round(2)}g restantes)")
    end
  end
end