class MakeSedeOptionalOnMovimientosContables < ActiveRecord::Migration[7.2]
  # La sede de un movimiento contable es opcional: el dashboard, el serializer y
  # el form ya contemplan "Sin sede". El belongs_to sin optional + el null: false
  # eran un olvido que provocaba un 422 al crear un movimiento sin sede.
  def up
    change_column_null :movimientos_contables, :sede_id, true
  end

  def down
    # Reversible solo si no hay movimientos sin sede; si los hubiera, volver a
    # null: false fallaría (esperado: no se debería revertir con datos nuevos).
    change_column_null :movimientos_contables, :sede_id, false
  end
end
