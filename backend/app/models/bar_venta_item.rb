# Línea de una venta del bar. `nombre` es un snapshot: el producto puede cambiar de nombre
# o borrarse y el ticket histórico se conserva.
#
# `vendible` es polimórfico: el mostrador vende de cualquier depósito (BarProducto del salón,
# Insumo de cultivo/general, Stock externo). `bar_producto` queda por compatibilidad — apunta a
# lo mismo cuando el vendible es un producto del bar, y es nil para el resto.
class BarVentaItem < ApplicationRecord
  acts_as_paranoid # soft-delete: la línea vuelve con su venta al restaurar
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :bar_venta
  belongs_to :bar_producto, optional: true
  belongs_to :vendible, polymorphic: true, optional: true

  # Líneas viejas (pre-F4) solo tienen bar_producto_id.
  def vendible_real = vendible || bar_producto

  validates :nombre, presence: true
  validates :cantidad, numericality: { greater_than: 0 }
  validates :precio_unitario_ars, :subtotal_ars, numericality: { greater_than_or_equal_to: 0 }
end
