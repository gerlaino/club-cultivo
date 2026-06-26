class AddStockResultanteToStockMovimientos < ActiveRecord::Migration[7.2]
  # Vincula el movimiento de producción (la salida de gramos del stock origen) con el stock
  # derivado que generó. Así, al borrar el derivado, se puede quitar ese movimiento del historial
  # del origen (igual que una dispensación borrada quita su movimiento), en vez de dejar rastro.
  def change
    add_reference :stock_movimientos, :stock_resultante, null: true,
                  foreign_key: { to_table: :stocks }
  end
end
