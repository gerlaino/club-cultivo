class AddPesoHumedoToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :peso_humedo, :decimal, precision: 8, scale: 2
  end
end
