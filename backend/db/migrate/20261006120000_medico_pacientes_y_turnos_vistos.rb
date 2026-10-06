# El bloque médico de Javi y Germán (6-oct-2026).
#
# · `medico_pacientes`: qué pacientes atiende cada médico. Un paciente puede tener más de uno. El
#   médico ve SÓLO a sus vinculados (`PacientePolicy::Scope`); administración vincula, y dar un
#   turno vincula solo.
# · `turnos.visto_at`: el médico confirma que vio el turno que le dieron.
# · `pacientes.reprocann_vinculo`: Vinculado (el REPROCANN está con la organización) o Adherente
#   (paciente nuevo con REPROCANN vigente, vinculado a OTRA organización por ahora). Vacío = sin dato.
# · `pacientes.reprocann_tramite_iniciado_el`: el día que se inició el trámite (botón «Inicié el trámite»).
# · `pacientes.apodo`: opcional; ayuda a encontrarlo, nunca sale en lo regulatorio.
#
# Rellenos, para que el deploy no deje a nadie a ciegas:
# · Hasta hoy el médico veía a TODOS los pacientes. Si la tabla nace vacía, mañana no ve a nadie.
#   Se vincula cada médico con los pacientes con los que YA tiene historia: un turno o una
#   indicación médica suya. El resto lo vincula administración.
# · Los turnos que ya existen nacen vistos: si no, cada médico abriría la agenda con todo «Nuevo».
class MedicoPacientesYTurnosVistos < ActiveRecord::Migration[7.2]
  def change
    create_table :medico_pacientes do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :medico,     null: false, foreign_key: { to_table: :users }
      t.references :paciente,   null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :medico_pacientes, %i[medico_id paciente_id], unique: true

    add_column :turnos,    :visto_at,                      :datetime
    add_column :pacientes, :reprocann_vinculo,             :string
    add_column :pacientes, :reprocann_tramite_iniciado_el, :date
    add_column :pacientes, :apodo,                         :string

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO medico_pacientes (club_id, medico_id, paciente_id, created_at, updated_at)
          SELECT DISTINCT p.club_id, h.medico_id, p.id, NOW(), NOW()
          FROM (
            SELECT medico_id, paciente_id FROM turnos WHERE deleted_at IS NULL
            UNION
            SELECT user_id, paciente_id FROM indicacion_medicas WHERE deleted_at IS NULL
          ) h
          JOIN pacientes p ON p.id = h.paciente_id
          JOIN users u ON u.id = h.medico_id AND u.role = 'medico' AND u.club_id = p.club_id
          ON CONFLICT (medico_id, paciente_id) DO NOTHING
        SQL
        execute "UPDATE turnos SET visto_at = created_at WHERE visto_at IS NULL"
      end
    end
  end
end
