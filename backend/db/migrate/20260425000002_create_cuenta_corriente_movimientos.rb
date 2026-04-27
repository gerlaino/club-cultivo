class CreateCuentaCorrienteMovimientos < ActiveRecord::Migration[7.2]
  def change
    create_table :cuenta_corriente_movimientos do |t|
      t.references :cuenta_corriente, null: false, foreign_key: true
      t.references :dispensacion,     null: true,  foreign_key: { to_table: :dispensaciones }
      t.references :created_by,       null: false,  foreign_key: { to_table: :users }
      t.string  :tipo,          null: false  # carga | debito | ajuste | pago
      t.decimal :monto,         precision: 12, scale: 2, null: false
      t.decimal :saldo_anterior, precision: 12, scale: 2, null: false
      t.decimal :saldo_nuevo,    precision: 12, scale: 2, null: false
      t.string  :descripcion
      t.timestamps
    end
  end
end
