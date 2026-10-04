# /BIENVENIDA CON DOS PUERTAS (Germán, 4-oct-2026, plan A).
#
# `registros_personales`: quien se registró SOLO para uso personal. La cuenta (club + usuario) se
# crea en el momento y entra al toque; esta fila guarda lo que el alta por super admin no tiene:
# la confirmación del mail (se pide después, con 7 días de gracia desde que el mail salió) y la
# PRUEBA de que aceptó los términos — qué versión, cuándo y desde qué IP. Sin esa constancia el
# consentimiento para tratar datos de salud (Ley 25.326, art. 7) no se puede demostrar.
#
# `solicitudes_contacto`: el formulario de la página (organizaciones, uso personal que prefiere
# hablar, y el «botón de arrepentimiento»). Se GUARDA y no sólo se manda por mail: si el correo
# falla, la consulta no se pierde — queda en la bandeja del super admin.
#
# Las dos son de PLATAFORMA, no de una organización: no llevan tenant.
class CrearRegistrosPersonalesYSolicitudesContacto < ActiveRecord::Migration[7.2]
  def change
    create_table :registros_personales do |t|
      t.references :club, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string   :email,               null: false
      t.string   :token_digest,        null: false
      t.datetime :mail_enviado_at
      t.datetime :confirmado_at
      t.string   :terminos_version,    null: false
      t.datetime :terminos_aceptados_at, null: false
      t.string   :ip
      t.string   :user_agent
      t.timestamps
    end
    add_index :registros_personales, :token_digest, unique: true

    create_table :solicitudes_contacto do |t|
      t.string   :tipo,         null: false
      t.string   :nombre,       null: false
      t.string   :email,        null: false
      t.string   :telefono
      t.string   :organizacion
      t.text     :mensaje
      t.string   :ip
      t.datetime :atendida_at
      t.references :atendida_por, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :solicitudes_contacto, :atendida_at
  end
end
