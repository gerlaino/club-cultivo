class AddEsSeleccionToPlants < ActiveRecord::Migration[7.2]
  def change
    add_column :plants, :es_seleccion, :boolean, null: false, default: false
    add_index  :plants, [:lote_id, :es_seleccion]
  end
end
