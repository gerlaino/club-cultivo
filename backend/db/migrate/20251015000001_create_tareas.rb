class CreateTareas < ActiveRecord::Migration[7.2]
  def change
    create_table :tareas do |t|
      t.references :club,         null: false, foreign_key: true
      t.references :asignada_a,   null: true,  foreign_key: { to_table: :users }
      t.references :creada_por,   null: false, foreign_key: { to_table: :users }
      t.references :sala,         null: true,  foreign_key: true
      t.references :lote,         null: true,  foreign_key: true
      t.references :plant,        null: true,  foreign_key: false

      t.string   :titulo,            null: false
      t.text     :descripcion
      t.string   :tipo,              null: false, default: 'otro'
      t.string   :estado,            null: false, default: 'pendiente'
      t.string   :prioridad,         null: false, default: 'normal'

      t.date     :fecha_programada
      t.datetime :fecha_completada

      t.decimal  :horas_estimadas,   precision: 5, scale: 2
      t.decimal  :horas_reales,      precision: 5, scale: 2
      t.text     :notas_completado

      # Para rastrear si las horas ya se aplicaron al costo del lote
      t.boolean  :horas_aplicadas_al_lote, null: false, default: false

      t.timestamps
    end

    add_index :tareas, [:club_id, :estado]
    add_index :tareas, [:club_id, :fecha_programada]
    add_index :tareas, [:asignada_a_id, :estado]
    add_index :tareas, [:lote_id, :horas_aplicadas_al_lote]
  end
end