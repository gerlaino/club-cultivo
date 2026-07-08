# Una venta del bar (ticket). Cabecera + líneas (BarVentaItem), con el mismo patrón que
# Dispensacion. El ingreso contable asociado vive en movimiento_contable. La creación con
# descuento de stock y asiento contable la maneja Bar::RegistrarVenta.
class BarVenta < ApplicationRecord
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :user # vendedor
  belongs_to :unidad_negocio,      optional: true
  belongs_to :movimiento_contable, optional: true
  has_many :items, class_name: 'BarVentaItem', dependent: :destroy

  MEDIOS_PAGO = %w[efectivo transferencia mercado_pago].freeze

  validates :total_ars, numericality: { greater_than_or_equal_to: 0 }
  validates :medio_pago, inclusion: { in: MEDIOS_PAGO }

  scope :del_dia, ->(fecha = Time.zone.today) { where(created_at: fecha.all_day) }
  scope :recientes, -> { order(created_at: :desc) }
end
