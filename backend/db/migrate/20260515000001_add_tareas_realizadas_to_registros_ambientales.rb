class AddTareasRealizadasToRegistrosAmbientales < ActiveRecord::Migration[7.2]
  def change
    add_column :registros_ambientales, :tareas_realizadas, :jsonb, default: [], null: false
  end
end
