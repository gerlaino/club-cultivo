# Un envío masivo: el mismo texto a muchos destinatarios, mandado UNO POR UNO.
#
# La tabla existe para que quede el rastro —quién mandó qué, a cuántos, cuántos salieron y
# cuáles fallaron—. Sin esto, un envío que sale a medias es invisible: nadie sabe a quién le
# llegó y a quién habría que reenviarle.
#
# `destinatarios` guarda la lista resuelta al momento de mandar (email + a quién corresponde),
# y `resultados` qué pasó con cada uno. Van en jsonb y no en una tabla aparte porque no se
# consultan por separado: se leen siempre junto al envío que los agrupa.
class CreateEnviosMasivos < ActiveRecord::Migration[7.2]
  def change
    create_table :envios_masivos do |t|
      t.references :club, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true          # quién lo mandó
      t.references :plantilla_mail, foreign_key: { to_table: :plantillas_mail }
      t.string  :asunto, null: false
      t.text    :cuerpo, null: false
      # 'pacientes' | 'libre' — a la nómina o a direcciones escritas a mano. No se mezclan: las
      # variables de plantilla ({{nombre}}) sólo tienen sentido con un paciente detrás.
      t.string  :destino, null: false, default: 'pacientes'
      t.string  :estado,  null: false, default: 'pendiente'
      t.jsonb   :destinatarios, null: false, default: []
      t.jsonb   :resultados,    null: false, default: []
      t.integer :total,    null: false, default: 0
      t.integer :enviados, null: false, default: 0
      t.integer :fallidos, null: false, default: 0
      t.datetime :comenzado_at
      t.datetime :terminado_at
      t.datetime :deleted_at
      t.bigint   :deleted_by_id

      t.timestamps
    end

    add_index :envios_masivos, :deleted_at
    add_index :envios_masivos, %i[club_id created_at]
  end
end
