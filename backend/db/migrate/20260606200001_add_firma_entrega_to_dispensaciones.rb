class AddFirmaEntregaToDispensaciones < ActiveRecord::Migration[7.2]
  def change
    add_column :dispensaciones, :firma_entrega_data, :text
  end
end
