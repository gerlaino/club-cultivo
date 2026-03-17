class AddFieldsToGeneticas < ActiveRecord::Migration[7.2]
  def change
    add_column :geneticas, :origen, :string
    add_column :geneticas, :tiempo_floracion, :integer
    add_column :geneticas, :rendimiento, :integer
    add_column :geneticas, :altura, :integer
    add_column :geneticas, :dificultad, :string
  end
end
