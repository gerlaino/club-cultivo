class AddLoteIdToAlertasInternas < ActiveRecord::Migration[7.1]
  def change
    add_reference :alertas_internas, :lote, foreign_key: true, null: true
  end
end
