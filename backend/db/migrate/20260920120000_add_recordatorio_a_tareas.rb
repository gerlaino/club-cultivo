# «Recordarme» al crear una tarea: `mismo_dia` / `dia_antes` (a las 8) o nada. Reemplaza al
# resumen genérico de las 8:00. `recordatorio_enviado_at` evita mandarlo dos veces y se
# limpia si cambia la fecha o el recordatorio.
class AddRecordatorioATareas < ActiveRecord::Migration[7.2]
  def change
    add_column :tareas, :recordatorio, :string
    add_column :tareas, :recordatorio_enviado_at, :datetime
    add_index  :tareas, [:recordatorio, :fecha_programada], where: 'recordatorio IS NOT NULL AND recordatorio_enviado_at IS NULL',
               name: 'index_tareas_recordatorios_pendientes'
  end
end
