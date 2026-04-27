class AddMedioPagoToDispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column :dispensaciones, :medio_pago, :string, default: 'efectivo', null: false
    add_index  :dispensaciones, :medio_pago
  end
end
