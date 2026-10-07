# El precio de una dispensa no se tipea (7-oct-2026): es la suma del carrito menos los
# descuentos. Para cobrar menos hay un descuento, en % (`descuento_dispensa_pct`) o en pesos
# (éste). Queda guardado para que la dispensa diga después POR QUÉ salió más barata: un %
# de dos decimales no representa un monto exacto ($5.000 sobre $105.000 es 4,7619…%).
class AgregarDescuentoEnPesosADispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column :dispensaciones, :descuento_dispensa_ars, :decimal, precision: 10, scale: 2, default: 0, null: false
  end
end
