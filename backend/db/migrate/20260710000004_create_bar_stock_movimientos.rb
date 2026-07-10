class CreateBarStockMovimientos < ActiveRecord::Migration[7.2]
  # Ledger de stock de los productos del bar (deposito_bar). Cada cambio de stock deja un
  # movimiento: entradas por compra / devolución de evento, salidas por venta / reserva de evento,
  # y ajustes (merma). Da trazabilidad y permite auditar el depósito del salón.
  def change
    create_table :bar_stock_movimientos do |t|
      t.references :club,         null: false, foreign_key: true
      t.references :bar_producto, null: false, foreign_key: true
      t.references :created_by,   null: false, foreign_key: { to_table: :users }
      # referencias opcionales según el origen del movimiento
      t.references :movimiento_contable, null: true, foreign_key: { to_table: :movimientos_contables }
      t.references :bar_venta,           null: true, foreign_key: { to_table: :bar_ventas }
      t.references :evento_bar,          null: true, foreign_key: { to_table: :eventos_bar }

      t.string   :tipo, null: false # compra | venta | reserva_evento | devolucion_evento | ajuste | merma
      t.decimal  :cantidad,           precision: 12, scale: 2, null: false # siempre > 0; el tipo da el signo
      t.decimal  :stock_anterior,     precision: 12, scale: 2, null: false
      t.decimal  :stock_nuevo,        precision: 12, scale: 2, null: false
      t.decimal  :costo_unitario_ars, precision: 12, scale: 2 # en compras, el costo de esta entrada
      t.string   :motivo

      t.timestamps
    end

    add_index :bar_stock_movimientos, [:bar_producto_id, :created_at]
    add_index :bar_stock_movimientos, :tipo
  end
end
