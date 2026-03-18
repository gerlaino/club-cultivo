class AddSedeToSalasAndEsqueje < ActiveRecord::Migration[7.2]
  def change
    add_column :salas, :plants_max, :integer, default: 0
    add_column :plants, :planta_madre_id, :bigint, null: true
    add_column :plants, :origen, :string, default: 'semilla'
    add_index :plants, :planta_madre_id
    add_index :plants, :origen
  end
end
