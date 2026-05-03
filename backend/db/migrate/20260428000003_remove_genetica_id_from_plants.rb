class RemoveGeneticaIdFromPlants < ActiveRecord::Migration[7.2]
  def up
    remove_index  :plants, :genetica_id, if_exists: true
    remove_column :plants, :genetica_id
  end

  def down
    add_column :plants, :genetica_id, :bigint
    add_index  :plants, :genetica_id
  end
end
