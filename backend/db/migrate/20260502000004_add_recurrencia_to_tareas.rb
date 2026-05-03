class AddRecurrenciaToTareas < ActiveRecord::Migration[7.1]
  def change
    add_column :tareas, :recurrente,         :boolean, default: false, null: false
    add_column :tareas, :frecuencia,          :string
    add_column :tareas, :intervalo,           :integer, default: 1
    add_column :tareas, :recurrencia_hasta,   :date
    add_column :tareas, :recurrencia_veces,   :integer
    add_column :tareas, :parent_tarea_id,     :integer
    add_index  :tareas, :parent_tarea_id
  end
end
