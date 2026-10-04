# Responder una consulta de /bienvenida desde el super admin (Germán, 4-oct-2026). La respuesta sale
# por el correo de la PLATAFORMA (hoy Gmail, mañana el corporativo: sólo cambian las variables de
# Render) y queda guardada acá: es el historial de la conversación con quien escribió.
# `enviada_at` lo anota el job cuando el correo la aceptó; `error`, si no pudo.
class CrearConsultaRespuestas < ActiveRecord::Migration[7.2]
  def change
    create_table :consulta_respuestas do |t|
      t.references :solicitud_contacto, null: false, foreign_key: { to_table: :solicitudes_contacto }
      t.references :user, null: false, foreign_key: true
      t.text     :texto, null: false
      t.datetime :enviada_at
      t.string   :error
      t.timestamps
    end
  end
end
