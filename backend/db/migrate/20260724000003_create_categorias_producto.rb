class CreateCategoriasProducto < ActiveRecord::Migration[7.2]
  # Categorías de producto EDITABLES del salón (Bebidas, Cocina, Merch…) — reemplazan al enum
  # hardcodeado BarProducto::CATEGORIAS. Aditivo: el enum `categoria` se conserva por compat
  # hasta que el POS lea de acá (C2.2). Y el producto del bar pasa a colgar de un depósito.
  def change
    create_table :categorias_producto do |t|
      t.references :club, null: false, foreign_key: true
      t.string  :nombre,        null: false
      t.integer :orden,         null: false, default: 0
      t.boolean :activo,        null: false, default: true
      t.boolean :es_sistema,    null: false, default: false
      t.string  :clave_sistema # bebida/cocina/merch/otro — para el backfill del enum
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :categorias_producto, :deleted_at
    add_index :categorias_producto, [:club_id, :clave_sistema]

    # to_table explícito: la tabla es 'categorias_producto' (plural español), Rails infiere
    # mal 'categoria_productos'.
    add_reference :bar_productos, :categoria_producto, foreign_key: { to_table: :categorias_producto }
    add_reference :bar_productos, :deposito,           foreign_key: true
  end
end
