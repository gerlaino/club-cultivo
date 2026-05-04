class AddPasadaCosechaToPlants < ActiveRecord::Migration[7.2]
  def up
    add_column :plants, :pasada_cosecha, :string
    add_index  :plants, [:lote_id, :pasada_cosecha], name: 'idx_plants_lote_pasada'

    # Existing cosechado plants get default pasada 'A'
    execute "UPDATE plants SET pasada_cosecha = 'A' WHERE state = 'cosechado' AND pasada_cosecha IS NULL"
  end

  def down
    remove_index  :plants, name: 'idx_plants_lote_pasada'
    remove_column :plants, :pasada_cosecha
  end
end
