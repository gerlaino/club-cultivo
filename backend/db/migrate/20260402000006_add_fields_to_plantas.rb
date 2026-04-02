class AddFieldsToPlantas < ActiveRecord::Migration[7.2]
  def change
    add_column :plants, :altura_actual, :decimal, precision: 6, scale: 1
    add_column :plants, :num_colas,     :integer
    add_column :plants, :estado_salud,  :string
    add_column :plants, :color_hojas,   :string
  end
end