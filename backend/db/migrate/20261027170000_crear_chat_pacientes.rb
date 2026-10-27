# El chat del portal: el paciente le escribe a su organización y la organización le contesta
# (27-oct-2026, Germán: «que desde el portal se le pueda mandar mensajes a la organización, y que
# el mensaje aparezca al admin dentro de la ficha de cada paciente, con la alerta correspondiente,
# armado tipo chat»).
#
# Una conversación por paciente (no hay temas ni hilos: es un chat). En ella vive lo que se lee de
# un vistazo: hasta cuándo leyó cada lado (de ahí salen los tildes y los «sin leer») y si la
# organización la dio por resuelta. Los mensajes llevan el texto CIFRADO —el paciente escribe de
# su salud— y pueden citar una dispensa suya («Consultar por esta dispensa») y traer un adjunto.
class CrearChatPacientes < ActiveRecord::Migration[7.2]
  def change
    create_table :conversaciones_paciente do |t|
      t.references :club,     null: false, foreign_key: true
      t.references :paciente, null: false, foreign_key: { to_table: :pacientes }, index: { unique: true }
      t.datetime :ultimo_mensaje_at
      t.string   :ultimo_autor
      t.datetime :leida_org_at
      t.datetime :leida_paciente_at
      t.datetime :resuelta_at
      t.references :resuelta_por, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :conversaciones_paciente, [:club_id, :ultimo_mensaje_at]

    create_table :mensajes_paciente do |t|
      t.references :club,         null: false, foreign_key: true
      t.references :conversacion, null: false, foreign_key: { to_table: :conversaciones_paciente }
      t.references :user,         foreign_key: true
      t.string     :autor,        null: false
      t.text       :texto
      t.references :dispensacion, foreign_key: { to_table: :dispensaciones }
      t.timestamps
    end
    add_index :mensajes_paciente, [:conversacion_id, :created_at]
  end
end
