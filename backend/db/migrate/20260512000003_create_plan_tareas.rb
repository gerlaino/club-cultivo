class CreatePlanTareas < ActiveRecord::Migration[7.1]
  def change
    create_table :plan_tareas do |t|
      t.references :plan_trabajo, null: false, foreign_key: true
      t.references :responsable,  null: true,  foreign_key: { to_table: :users }
      t.references :sala,         null: true,  foreign_key: true
      t.references :tarea_generada, null: true, foreign_key: { to_table: :tareas }

      t.string   :titulo
      t.string   :tipo,             null: false, default: 'otro'
      t.string   :prioridad,        null: false, default: 'normal'
      t.text     :descripcion
      t.string   :dias_semana
      t.string   :hora
      t.boolean  :es_recurrente,    null: false, default: false
      t.string   :recurrencia_id
      t.date     :fecha_especifica
      t.boolean  :origen_ia,        null: false, default: false
      t.boolean  :confirmada,       null: false, default: true

      t.timestamps
    end

    add_index :plan_tareas, [:plan_trabajo_id, :es_recurrente]
    add_index :plan_tareas, :recurrencia_id
  end
end
