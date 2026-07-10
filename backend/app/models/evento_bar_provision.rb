# Provisión de un producto para un evento del bar. Ver flujo en la migración:
# prevista → (comprar faltante) → reservada (sale del depósito) → consumida → sobrante vuelve.
class EventoBarProvision < ApplicationRecord
  self.table_name = 'evento_bar_provisiones' # inflector EN no pluraliza "provision" bien

  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :evento_bar
  belongs_to :bar_producto

  validates :cantidad_prevista, :cantidad_reservada, :cantidad_consumida,
            numericality: { greater_than_or_equal_to: 0 }
  validates :bar_producto_id, uniqueness: { scope: :evento_bar_id }

  # Sobrante = lo reservado que no se consumió (vuelve al depósito al cerrar).
  def sobrante = (cantidad_reservada.to_d - cantidad_consumida.to_d)

  # Faltante para comprar = lo previsto que no está en el depósito del producto.
  def faltante = [cantidad_prevista.to_d - bar_producto.stock.to_d, 0].max
end
