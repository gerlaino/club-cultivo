class CreateTurnos < ActiveRecord::Migration[7.0]
  def change
    create_table :turnos do |t|
      t.references :paciente, null: false, foreign_key: true
      t.references :medico,   null: false, foreign_key: { to_table: :users }
      t.references :club,     null: false, foreign_key: true
      t.datetime   :fecha_hora, null: false
      t.integer    :duracion_minutos, null: false, default: 30
      t.string     :tipo,    null: false, default: 'seguimiento'  # primera_vez | seguimiento | revision | urgencia
      t.string     :estado,  null: false, default: 'programado'   # programado | confirmado | realizado | cancelado | ausente
      t.text       :motivo
      t.text       :notas_post  # notas del médico post-consulta
      t.timestamps
    end

    add_index :turnos, [:club_id, :fecha_hora]
    add_index :turnos, [:medico_id, :fecha_hora]
    add_index :turnos, [:paciente_id, :fecha_hora]
  end
end
