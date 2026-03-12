class ChangeGeneticaIdToNullableInPlants < ActiveRecord::Migration[7.2]
  def change
    change_column_null :plants, :genetica_id, true
  end
end
