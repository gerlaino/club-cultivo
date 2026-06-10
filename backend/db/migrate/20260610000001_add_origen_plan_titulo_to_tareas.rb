class AddOrigenPlanTituloToTareas < ActiveRecord::Migration[7.1]
  def up
    add_column :tareas, :origen_plan_titulo, :string

    execute <<~SQL
      UPDATE tareas
      SET origen_plan_titulo = plan_trabajos.titulo
      FROM plan_trabajos
      WHERE tareas.origen_plan_id = plan_trabajos.id
    SQL
  end

  def down
    remove_column :tareas, :origen_plan_titulo
  end
end
