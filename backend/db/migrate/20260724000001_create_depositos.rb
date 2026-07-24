class CreateDepositos < ActiveRecord::Migration[7.2]
  def change
    create_table :depositos do |t|
      t.references :club, null: false, foreign_key: true
      t.string  :nombre,        null: false
      # clave_sistema: cultivo / general / salon / dispensacion para los de sistema; nil = propio del club.
      t.string  :clave_sistema
      t.boolean :es_sistema,    null: false, default: false
      t.boolean :activo,        null: false, default: true
      t.integer :orden,         null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :depositos, :deleted_at
    add_index :depositos, [:club_id, :clave_sistema]

    # El insumo pasa a vivir en un depósito. Se backfillea desde `tipo` en la siembra.
    # `tipo` (cultivo/general) se conserva por ahora (compatibilidad) hasta unificar en Producto.
    add_reference :insumos, :deposito, foreign_key: true
  end
end
