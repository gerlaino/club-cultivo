class AddMontoCreditoToDispensaciones < ActiveRecord::Migration[7.2]
  # Parte del total que cae sobre la cuenta corriente (crédito). La diferencia
  # (aporte_socio_ars - monto_credito_ars) es lo que se cobra ahora en efectivo.
  def change
    add_column :dispensaciones, :monto_credito_ars, :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
