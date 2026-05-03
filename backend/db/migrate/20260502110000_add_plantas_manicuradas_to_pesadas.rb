class AddPlantasManicuradasToPesadas < ActiveRecord::Migration[7.2]
  def change
    add_column :pesadas, :plantas_manicuradas, :integer
  end
end
