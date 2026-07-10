class CreateCajaTurnos < ActiveRecord::Migration[7.2]
  # Caja de turno del salón: apertura con fondo inicial, cierre con arqueo (efectivo contado
  # vs esperado). Las ventas del turno se enganchan por caja_turno_id. Una sola caja abierta
  # por bar a la vez (índice único parcial sobre estado='abierta').
  def change
    create_table :caja_turnos do |t|
      t.references :club, null: false, foreign_key: true
      t.references :bar,  null: false, foreign_key: { to_table: :bares }
      t.references :sede, null: false, foreign_key: true
      t.references :abierta_por, null: false, foreign_key: { to_table: :users }
      t.references :cerrada_por, foreign_key: { to_table: :users }

      t.string   :estado,                 null: false, default: 'abierta' # abierta | cerrada
      t.decimal  :monto_inicial_ars,      precision: 12, scale: 2, null: false, default: 0
      t.decimal  :efectivo_declarado_ars, precision: 12, scale: 2 # contado al cerrar
      t.datetime :abierta_at,             null: false
      t.datetime :cerrada_at
      t.string   :notas

      t.timestamps
    end

    # Una sola caja abierta por bar.
    add_index :caja_turnos, :bar_id, unique: true, where: "estado = 'abierta'",
              name: 'index_caja_turnos_una_abierta_por_bar'

    add_reference :bar_ventas, :caja_turno, foreign_key: true
  end
end
