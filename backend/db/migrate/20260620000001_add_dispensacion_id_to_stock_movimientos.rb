class AddDispensacionIdToStockMovimientos < ActiveRecord::Migration[7.2]
  # Vincula el movimiento de stock con la dispensación que lo generó, para poder
  # borrarlo de forma exacta al eliminar la dispensación (antes se borraba por
  # texto en `notas`, frágil: fallaba con dispensas viejas o venidas de reserva).
  def change
    add_column :stock_movimientos, :dispensacion_id, :bigint
    add_index  :stock_movimientos, :dispensacion_id
  end
end
