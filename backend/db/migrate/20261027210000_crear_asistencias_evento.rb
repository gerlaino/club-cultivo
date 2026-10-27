# «Asistiré» en los eventos del portal (27-oct-2026, Germán: «en eventos en lugar de me anoto
# debería decir asistiré»). El paciente marca que va y la organización ve quién va y cuántos son.
# Uno por paciente y evento.
class CrearAsistenciasEvento < ActiveRecord::Migration[7.2]
  def change
    create_table :asistencias_evento do |t|
      t.references :club,     null: false, foreign_key: true
      t.references :evento,   null: false, foreign_key: true
      t.references :paciente, null: false, foreign_key: { to_table: :pacientes }
      t.timestamps
    end
    add_index :asistencias_evento, [:evento_id, :paciente_id], unique: true
  end
end
