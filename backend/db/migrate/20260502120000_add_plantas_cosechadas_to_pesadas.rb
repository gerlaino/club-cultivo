class AddPlantasCosechadasToPesadas < ActiveRecord::Migration[7.2]
  def change
    add_column :pesadas, :plantas_cosechadas, :integer
  end
end
