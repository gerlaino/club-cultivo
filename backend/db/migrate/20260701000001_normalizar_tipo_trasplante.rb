class NormalizarTipoTrasplante < ActiveRecord::Migration[7.2]
  # Canonicaliza el tipo de tarea a 'trasplante' (castellano correcto, usado por
  # LoteEvento, el servicio de IA y el 90% del front). Tarea/PlanTarea usaban
  # 'transplante' (sin s), lo que hacía fallar la validación de tareas de trasplante
  # generadas por IA. Migra los datos existentes; reversible.
  def up
    execute "UPDATE tareas SET tipo = 'trasplante' WHERE tipo = 'transplante'"
    execute "UPDATE plan_tareas SET tipo = 'trasplante' WHERE tipo = 'transplante'"
  end

  def down
    execute "UPDATE tareas SET tipo = 'transplante' WHERE tipo = 'trasplante'"
    execute "UPDATE plan_tareas SET tipo = 'transplante' WHERE tipo = 'trasplante'"
  end
end
