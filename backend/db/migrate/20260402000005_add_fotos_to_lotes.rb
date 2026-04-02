class AddFotosToLotes < ActiveRecord::Migration[7.2]
  def change
    # ActiveStorage ya tiene las tablas, no necesitamos nada extra
    # Solo agregamos el campo de notas de registro
    add_column :registros_ambientales, :fertilizacion,       :boolean, default: false
    add_column :registros_ambientales, :notas_fertilizacion, :text
  end
end