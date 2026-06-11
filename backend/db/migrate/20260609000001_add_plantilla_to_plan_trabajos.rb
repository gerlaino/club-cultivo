class AddPlantillaToPlanTrabajos < ActiveRecord::Migration[7.2]
  def change
    add_column :plan_trabajos, :es_plantilla, :boolean, default: false, null: false

    change_column_null :plan_trabajos, :fecha_inicio, true
    change_column_null :plan_trabajos, :fecha_fin,    true
    change_column_null :plan_trabajos, :periodo_tipo, true
  end
end
