class CreateBarVentas < ActiveRecord::Migration[7.2]
  # Una venta del bar (ticket). El ingreso contable asociado vive en movimiento_contable.
  def change
    create_table :bar_ventas do |t|
      t.references :club,                null: false, foreign_key: true
      t.references :user,                null: false, foreign_key: true # vendedor
      t.references :unidad_negocio,      null: true,  foreign_key: { to_table: :unidades_negocio }
      t.references :movimiento_contable, null: true,  foreign_key: { to_table: :movimientos_contables }
      t.decimal :total_ars, precision: 12, scale: 2, null: false, default: 0
      t.string  :medio_pago, null: false, default: 'efectivo' # efectivo/transferencia/mercado_pago
      t.string  :turno
      t.text    :notas
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :bar_ventas, :deleted_at
    add_index :bar_ventas, [:club_id, :created_at]
  end
end
