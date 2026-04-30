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
  validate  :credito_suficiente, on: :create

  scope :del_mes,   ->(fecha = Date.today) { where(fecha_dispensacion: fecha.beginning_of_month..fecha.end_of_month) }
  scope :del_paciente, ->(paciente_id) { where(paciente_id: paciente_id) }
  scope :recientes, -> { order(fecha_dispensacion: :desc, created_at: :desc) }

  after_create  :decrementar_stock
  after_create  :debitar_cuenta_corriente
  after_destroy :incrementar_stock

  private

  def fecha_no_futura
    errors.add(:fecha_dispensacion, 'no puede ser futura') if fecha_dispensacion.present? && fecha_dispensacion > Date.today
  end

  def stock_regulatorio
    errors.add(:stock, 'solo se pueden dispensar stocks regulatorios (de lote propio o derivado)') unless stock&.regulatorio?
  end

  def credito_suficiente
    return unless paciente_id && aporte_socio_ars.to_d > 0
    cc = paciente.cuenta_corriente
    return unless cc
    if cc.saldo_disponible < aporte_socio_ars.to_d
      errors.add(:aporte_socio_ars,
        "supera el crédito disponible del paciente (#{cc.saldo_disponible.to_f.round(2)} ARS disponibles)")
    end
  end

  def decrementar_stock
    stock&.decrement!(:cantidad, cantidad)
  end

  def incrementar_stock
    stock&.increment!(:cantidad, cantidad)
  end

  def debitar_cuenta_corriente
    return unless aporte_socio_ars.to_d > 0
    cc = paciente.cuenta_corriente
    return unless cc

    anterior = cc.saldo_disponible
    nuevo    = anterior - aporte_socio_ars.to_d

    cc.update!(saldo_disponible: nuevo)
    cc.movimientos.create!(
      tipo:           'debito',
      monto:          -aporte_socio_ars.to_d,
      saldo_anterior: anterior,
      saldo_nuevo:    nuevo,
      descripcion:    "Dispensación ##{id}",
      dispensacion:   self,
      created_by:     user
    )
  end
end
