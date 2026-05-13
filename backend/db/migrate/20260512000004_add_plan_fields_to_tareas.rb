class AddPlanFieldsToTareas < ActiveRecord::Migration[7.1]
  def change
    add_reference :tareas, :origen_plan,  null: true, foreign_key: { to_table: :plan_trabajos }
    add_reference :tareas, :plan_tarea,   null: true, foreign_key: { to_table: :plan_tareas }
  end
end
