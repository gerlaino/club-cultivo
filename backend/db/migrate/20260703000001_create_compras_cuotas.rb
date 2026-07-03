class CreateComprasCuotas < ActiveRecord::Migration[7.2]
  def change
    create_table :compras_cuotas do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :sede,       null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string  :descripcion,        null: false
      t.string  :categoria,          null: false
      t.decimal :monto_total_ars,    precision: 12, scale: 2, null: false
      t.integer :cuotas_total,       null: false
      t.date    :fecha_primera_cuota, null: false
      t.string  :medio_pago
      t.string  :responsable   # "Tarjeta del club", nombre de la persona, etc.
      t.string  :proveedor
      t.text    :notas
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :compras_cuotas, :deleted_at

    # Cada cuota es un movimiento contable, agrupado por la compra y numerado.
    add_reference :movimientos_contables, :compra_cuotas, null: true,
                  foreign_key: { to_table: :compras_cuotas }
    add_column    :movimientos_contables, :cuota_numero, :integer
  end
end
