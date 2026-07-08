class CreateBarProductos < ActiveRecord::Migration[7.2]
  # Producto del bar (café, cerveza, medialuna…). Stock propio, descontado en cada venta.
  def change
    create_table :bar_productos do |t|
      t.references :club,           null: false, foreign_key: true
      t.references :unidad_negocio, null: true,  foreign_key: { to_table: :unidades_negocio }
      t.string  :nombre,       null: false
      t.string  :categoria,    null: false, default: 'bebida' # bebida/cocina/merch/otro
      t.decimal :precio_ars,   precision: 12, scale: 2, null: false, default: 0
      t.decimal :costo_ars,    precision: 12, scale: 2 # costo de mercadería, para margen (opcional)
      t.decimal :stock,        precision: 12, scale: 2, null: false, default: 0
      t.decimal :stock_minimo, precision: 12, scale: 2, null: false, default: 0
      t.boolean :activo,       null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :bar_productos, :deleted_at
    add_index :bar_productos, [:club_id, :activo]
  end
end
