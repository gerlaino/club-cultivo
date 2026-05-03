class AddActivoToClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :activo, :boolean, default: true, null: false
  end
end
