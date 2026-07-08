class CreateBarVentaItems < ActiveRecord::Migration[7.2]
  # Línea de una venta del bar. `nombre` es un snapshot inmutable (el producto puede cambiar).
  def change
    create_table :bar_venta_items do |t|
      t.references :club,         null: false, foreign_key: true
      t.references :bar_venta,    null: false, foreign_key: { to_table: :bar_ventas }
      t.references :bar_producto, null: true,  foreign_key: { to_table: :bar_productos }
      t.string  :nombre,              null: false
      t.decimal :cantidad,            precision: 12, scale: 2, null: false
      t.decimal :precio_unitario_ars, precision: 12, scale: 2, null: false
      t.decimal :subtotal_ars,        precision: 12, scale: 2, null: false
      t.timestamps
    end
  end
end
