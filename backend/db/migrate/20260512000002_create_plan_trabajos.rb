class CreatePlanTrabajos < ActiveRecord::Migration[7.1]
  def change
    create_table :plan_trabajos do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :creado_por, null: false, foreign_key: { to_table: :users }
      t.references :sede,       null: true,  foreign_key: true

      t.string   :titulo,                  null: false
      t.integer  :periodo_tipo,            null: false, default: 0
      t.date     :fecha_inicio,            null: false
      t.date     :fecha_fin,               null: false
      t.integer  :estado,                  null: false, default: 0
      t.boolean  :repetir_automaticamente, null: false, default: false
      t.text     :notas
      t.datetime :publicado_en

      t.timestamps
    end

    add_index :plan_trabajos, [:club_id, :estado]
    add_index :plan_trabajos, [:club_id, :fecha_inicio]
  end
end
