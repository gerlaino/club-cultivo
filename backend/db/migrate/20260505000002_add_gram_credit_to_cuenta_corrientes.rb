class AddGramCreditToCuentaCorrientes < ActiveRecord::Migration[7.2]
  def change
    add_column :cuenta_corrientes, :credito_gramos_activo, :boolean, default: false, null: false
    add_column :cuenta_corrientes, :limite_credito_g,      :decimal, precision: 10, scale: 3
    add_column :cuenta_corrientes, :saldo_disponible_g,    :decimal, precision: 10, scale: 3, default: '0.0'
  end
end
