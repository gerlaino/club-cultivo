# Movimiento de stock de un producto del bar (deposito_bar). Ledger auditable: cada entrada/salida
# de stock deja su rastro con el saldo antes/después. No se borra (es historia contable de stock).
class BarStockMovimiento < ApplicationRecord
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :bar_producto
  belongs_to :created_by, class_name: 'User'
  belongs_to :movimiento_contable, optional: true
  belongs_to :bar_venta,           optional: true
  belongs_to :evento_bar,          optional: true

  TIPOS   = %w[compra venta reserva_evento devolucion_evento ajuste merma].freeze
  ENTRADAS = %w[compra devolucion_evento].freeze # suman stock
  SALIDAS  = %w[venta reserva_evento merma].freeze # restan stock (ajuste fija el valor)

  validates :tipo, inclusion: { in: TIPOS }
  validates :cantidad, numericality: { greater_than: 0 }

  scope :recientes, -> { order(created_at: :desc) }

  def entrada? = ENTRADAS.include?(tipo)
end
