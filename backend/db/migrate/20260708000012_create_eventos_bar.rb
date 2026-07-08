class CreateEventosBar < ActiveRecord::Migration[7.2]
  # Evento de un bar (fiesta, cata, taller) como proyecto con P&L propio. Se llama eventos_bar
  # para no chocar con el modelo Evento (eventos de socios) ya existente. El resultado se arma
  # desde el libro contable, etiquetando cada movimiento con evento_bar_id (una dimensión más).
  def change
    create_table :eventos_bar do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :bar,        null: false, foreign_key: { to_table: :bares }
      t.references :deleted_by, null: true,  foreign_key: { to_table: :users }
      t.string  :nombre, null: false
      t.date    :fecha
      t.string  :estado, null: false, default: 'planificado' # planificado/en_venta/en_curso/finalizado/cancelado
      t.text    :descripcion
      t.integer :aforo
      t.decimal :presupuesto_ingresos, precision: 12, scale: 2, null: false, default: 0
      t.text    :notas
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :eventos_bar, :deleted_at
    add_index :eventos_bar, [:club_id, :fecha]

    create_table :evento_bar_costos do |t|
      t.references :club,                null: false, foreign_key: true
      t.references :evento_bar,          null: false, foreign_key: { to_table: :eventos_bar }
      t.references :movimiento_contable, null: true,  foreign_key: { to_table: :movimientos_contables }
      t.references :created_by,          null: false, foreign_key: { to_table: :users }
      t.references :deleted_by,          null: true,  foreign_key: { to_table: :users }
      t.string  :concepto, null: false          # "DJ", "Seguridad", "Sonido"…
      t.string  :proveedor
      t.decimal :monto_ars, precision: 12, scale: 2, null: false
      t.boolean :pagado, null: false, default: false
      t.date    :fecha
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :evento_bar_costos, :deleted_at

    create_table :evento_bar_tareas do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :evento_bar, null: false, foreign_key: { to_table: :eventos_bar }
      t.references :deleted_by, null: true,  foreign_key: { to_table: :users }
      t.string  :titulo, null: false
      t.boolean :hecha,  null: false, default: false
      t.date    :vence_el
      t.integer :orden,  null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :evento_bar_tareas, :deleted_at

    # evento_bar_id como dimensión del libro y de las ventas del bar (atribución al evento).
    add_reference :movimientos_contables, :evento_bar, null: true, foreign_key: { to_table: :eventos_bar }
    add_reference :bar_ventas,            :evento_bar, null: true, foreign_key: { to_table: :eventos_bar }
  end
end
