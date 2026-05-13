class AddOrigenPlantaMadreToLotes < ActiveRecord::Migration[7.1]
  def change
    add_column     :lotes, :origen, :string, default: 'semilla', null: false
    add_reference  :lotes, :planta_madre, null: true, foreign_key: { to_table: :plants }
  end
end
