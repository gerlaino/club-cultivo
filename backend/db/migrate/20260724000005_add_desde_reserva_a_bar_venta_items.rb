class AddDesdeReservaABarVentaItems < ActiveRecord::Migration[7.2]
  # Cuánto de la línea salió de la RESERVA del evento (no del stock). Necesario para revertir
  # bien al borrar la venta: la parte de reserva vuelve a la provisión, no infla el stock.
  def change
    add_column :bar_venta_items, :cantidad_desde_reserva, :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
