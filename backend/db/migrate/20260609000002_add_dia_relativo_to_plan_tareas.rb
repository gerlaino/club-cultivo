class AddDiaRelativoToPlanTareas < ActiveRecord::Migration[7.2]
  def change
    add_column :plan_tareas, :dia_relativo, :integer
    add_column :plan_tareas, :rol_sugerido, :string
  end
end
