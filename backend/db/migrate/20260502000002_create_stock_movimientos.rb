class CreateStockMovimientos < ActiveRecord::Migration[7.2]
  def change
    create_table :stock_movimientos do |t|
      t.references :stock,        null: false, foreign_key: true
      t.string     :tipo,         null: false  # produccion | transferencia | dispensacion | ajuste | merma
      t.decimal    :gramos,       precision: 10, scale: 2, null: false
      t.bigint     :sede_origen_id
      t.bigint     :sede_destino_id
      t.references :usuario,      null: false, foreign_key: { to_table: :users }
      t.text       :notas
      t.timestamps null: false
    end

    add_index :stock_movimientos, :tipo
    add_index :stock_movimientos, :sede_origen_id
    add_index :stock_movimientos, :sede_destino_id
    add_foreign_key :stock_movimientos, :sedes, column: :sede_origen_id
    add_foreign_key :stock_movimientos, :sedes, column: :sede_destino_id
  end
end
