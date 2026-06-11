class CreateDisponibilidadMedicos < ActiveRecord::Migration[7.0]
  def change
    create_table :disponibilidad_medicos do |t|
      t.references :medico, null: false, foreign_key: { to_table: :users }
      t.references :club,   null: false, foreign_key: true
      t.integer    :dia_semana,  null: false  # 0=lunes … 6=domingo
      t.integer    :hora_inicio, null: false  # minutos desde medianoche (ej: 540 = 9:00)
      t.integer    :hora_fin,    null: false  # minutos desde medianoche (ej: 780 = 13:00)
      t.boolean    :activa, null: false, default: true
      t.timestamps
    end
    add_index :disponibilidad_medicos, [:medico_id, :dia_semana]
    add_index :disponibilidad_medicos, [:club_id, :medico_id]
  end
end
