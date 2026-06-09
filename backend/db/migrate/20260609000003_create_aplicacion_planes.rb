class CreateAplicacionPlanes < ActiveRecord::Migration[7.2]
  def change
    create_table :aplicacion_planes do |t|
      t.references :plan_trabajo,   null: false, foreign_key: true
      t.references :club,           null: false, foreign_key: true
      t.references :aplicado_por,   null: false, foreign_key: { to_table: :users }
      t.string     :objetivo_tipo                       # 'Lote' | 'Sala'
      t.integer    :objetivo_id
      t.date       :fecha_inicio,   null: false
      t.string     :estado,         null: false, default: 'activo'
      t.integer    :tareas_creadas, default: 0
      t.timestamps
    end

    add_index :aplicacion_planes, [:club_id, :estado]
    add_index :aplicacion_planes, [:objetivo_tipo, :objetivo_id]

    add_column    :tareas, :aplicacion_plan_id, :bigint
    add_index     :tareas, :aplicacion_plan_id
    add_foreign_key :tareas, :aplicacion_planes, column: :aplicacion_plan_id
  end
end
