# La entrada al portal del paciente (27-oct-2026, Germán: «que los pacientes directamente ya puedan
# usar el portal, teniendo en cuenta todas las entradas»).
#
# Hasta hoy el paciente entraba con un usuario inventado (`nombre.apellido@org.paciente`) y una
# contraseña que el admin veía UNA vez y le tenía que dictar; si se la olvidaba no podía
# recuperarla. Ahora entra con su DNI y elige su clave desde un link:
#
#   - `invitacion`: el que manda la organización (al admitirlo o desde la ficha). Vale 72 horas.
#   - `recuperacion`: el que pide él con «Me olvidé la clave». Vale 6 horas, como el del equipo.
#
# Un link sirve UNA vez, pide el DNI (si se lo reenvían a otro, no le sirve) y se cae solo después
# de 5 DNI equivocados. En la base queda el HASH del token, nunca el token: con una copia de la
# base no se puede entrar a ninguna cuenta.
class CrearAccesosPortal < ActiveRecord::Migration[7.2]
  def change
    create_table :accesos_portal do |t|
      t.references :club,     null: false, foreign_key: true
      t.references :paciente, null: false, foreign_key: { to_table: :pacientes }
      t.references :creado_por, foreign_key: { to_table: :users }
      t.string   :motivo,       null: false, default: 'invitacion'
      t.string   :token_digest, null: false
      t.datetime :expira_at,    null: false
      t.datetime :usado_at
      t.datetime :anulado_at
      t.integer  :intentos_fallidos, null: false, default: 0
      t.timestamps
    end
    add_index :accesos_portal, :token_digest, unique: true
    add_index :accesos_portal, [:paciente_id, :usado_at]
  end
end
