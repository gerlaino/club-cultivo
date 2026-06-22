class AddCantidadInicialToStocks < ActiveRecord::Migration[7.2]
  def up
    add_column :stocks, :cantidad_inicial, :decimal, precision: 10, scale: 2

    # Backfill: "lo que entró" = suma de movimientos de producción (>0); si el stock no
    # tiene movimientos de producción (compra externa, derivados), usa la cantidad actual.
    execute <<~SQL.squish
      UPDATE stocks s SET cantidad_inicial = COALESCE(
        (SELECT SUM(sm.gramos) FROM stock_movimientos sm
          WHERE sm.stock_id = s.id AND sm.tipo = 'produccion' AND sm.gramos > 0),
        s.cantidad
      )
    SQL
  end

  def down
    remove_column :stocks, :cantidad_inicial
  end
end
