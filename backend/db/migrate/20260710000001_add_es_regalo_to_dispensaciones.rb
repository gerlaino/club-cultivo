class AddEsRegaloToDispensaciones < ActiveRecord::Migration[7.2]
  # Regalo: una dispensa entregada gratis (no cobra, no toca cuenta corriente ni crédito).
  # El stock igual se descuenta (el producto sale). Queda trazada como regalo.
  def change
    add_column :dispensaciones, :es_regalo, :boolean, default: false, null: false
  end
end
