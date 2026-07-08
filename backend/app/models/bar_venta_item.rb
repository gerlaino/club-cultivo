# Línea de una venta del bar. `nombre` es un snapshot: el producto puede cambiar de nombre
# o borrarse y el ticket histórico se conserva.
class BarVentaItem < ApplicationRecord
  acts_as_paranoid # soft-delete: la línea vuelve con su venta al restaurar
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :bar_venta
  belongs_to :bar_producto, optional: true

  validates :nombre, presence: true
  validates :cantidad, numericality: { greater_than: 0 }
  validates :precio_unitario_ars, :subtotal_ars, numericality: { greater_than_or_equal_to: 0 }
end
