class Dispensacion < ApplicationRecord
  self.table_name = 'dispensaciones'

  belongs_to :paciente
  belongs_to :user
  belongs_to :indicacion_medica, optional: true
  belongs_to :stock
  belongs_to :sede, optional: true

  has_one :movimiento_contable, dependent: :nullify

  before_validation { self.fecha_dispensacion ||= Date.current }

  validates :cantidad,           presence: true, numericality: { greater_than: 0 }
  validates :fecha_dispensacion, presence: true
  validate  :fecha_no_futura
  validate  :stock_regulatorio
  validate  :stock_disponible,   on: :create
  validate  :credito_suficiente, on: :create, if: -> { medio_pago == 'cuenta_corriente' }

  scope :del_mes,   ->(fecha = Date.today) { where(fecha_dispensacion: fecha.beginning_of_month..fecha.end_of_month) }
  scope :del_paciente, ->(paciente_id) { where(paciente_id: paciente_id) }
  scope :recientes, -> { order(fecha_dispensacion: :desc, created_at: :desc) }

  after_create  :decrementar_stock
  after_destroy :incrementar_stock

  private

  def fecha_no_futura
    errors.add(:fecha_dispensacion, 'no puede ser futura') if fecha_dispensacion.present? && fecha_dispensacion > Date.today
  end

  def stock_regulatorio
    errors.add(:stock, 'solo se pueden dispensar stocks regulatorios (de lote propio o derivado)') unless stock&.regulatorio?
  end

  def stock_disponible
    return unless stock && cantidad.to_d > 0
    if cantidad.to_d > stock.cantidad.to_d
      errors.add(:cantidad,
        "supera el stock disponible (#{stock.cantidad.to_f} #{stock.unidad || 'g'} disponibles)")
    end
  end

  def credito_suficiente
    return unless paciente_id && aporte_socio_ars.to_d > 0
    cc = paciente.cuenta_corriente
    return unless cc
    margen = cc.saldo_disponible + cc.limite_credito
    if margen < aporte_socio_ars.to_d
      errors.add(:aporte_socio_ars,
        "supera el crédito disponible del paciente (#{margen.to_f.round(2)} ARS disponibles)")
    end
  end

  def decrementar_stock
    stock&.decrement!(:cantidad, cantidad)
  end

  def incrementar_stock
    stock&.increment!(:cantidad, cantidad)
  end

end
