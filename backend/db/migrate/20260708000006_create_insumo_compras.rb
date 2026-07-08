class CreateInsumoCompras < ActiveRecord::Migration[7.2]
  # Una entrada de stock de insumo (compra). Puede generar un egreso en el libro
  # contable (movimiento_contable_id) — la plata sale al comprar, no al consumir.
  def change
    create_table :insumo_compras do |t|
      t.references :club,                null: false, foreign_key: true
      t.references :insumo,              null: false, foreign_key: true
      t.references :movimiento_contable, null: true,  foreign_key: { to_table: :movimientos_contables }
      t.references :created_by,          null: false, foreign_key: { to_table: :users }
      t.decimal :cantidad,           precision: 14, scale: 3, null: false
      t.decimal :costo_total_ars,    precision: 14, scale: 2, null: false
      t.decimal :costo_unitario_ars, precision: 14, scale: 4, null: false
      t.string  :proveedor
      t.date    :fecha, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :insumo_compras, :deleted_at
  end
end
