# Ver crecer la planta. Las fotos del lote eran adjuntos sueltos (`Lote has_many_attached :fotos`)
# con la descripción escondida en el metadata del blob: no se podían ordenar por el día del
# cultivo, ni etiquetar, ni saber en qué fase se sacaron. `lote_fotos` es una fila por foto con
# lo que hace falta para una línea de tiempo: cuándo, en qué fase, de qué planta, con qué
# etiquetas y qué nota. La imagen sigue en Active Storage (misma tabla de blobs).
#
# Migra lo que ya había: cada adjunto viejo pasa a ser una fila apuntando al MISMO blob (se
# borra el adjunto viejo sin purgar, para no borrar la imagen). `lotes.foto_portada_blob_id`
# sigue valiendo: apunta al blob, no al adjunto.
class CrearLoteFotos < ActiveRecord::Migration[7.2]
  def up
    create_table :lote_fotos do |t|
      t.references :club,  null: false, foreign_key: true
      t.references :lote,  null: false, foreign_key: true
      t.references :plant, null: true,  foreign_key: true
      t.references :user,  null: true,  foreign_key: true
      t.date   :tomada_el, null: false
      t.string :fase
      t.jsonb  :etiquetas, null: false, default: []
      t.string :nota
      t.timestamps
    end
    add_index :lote_fotos, [:lote_id, :tomada_el]
    add_index :lote_fotos, :etiquetas, using: :gin

    execute <<~SQL
      INSERT INTO lote_fotos (club_id, lote_id, tomada_el, fase, nota, created_at, updated_at)
      SELECT l.club_id, a.record_id, (b.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
             NULL, NULLIF(b.metadata::jsonb->>'descripcion', ''), b.created_at, b.created_at
      FROM active_storage_attachments a
      JOIN active_storage_blobs b ON b.id = a.blob_id
      JOIN lotes l ON l.id = a.record_id
      WHERE a.record_type = 'Lote' AND a.name = 'fotos'
    SQL
    # Cada fila nueva recibe su adjunto `imagen` apuntando al mismo blob, en el mismo orden.
    execute <<~SQL
      INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
      SELECT 'imagen', 'LoteFoto', f.id, a.blob_id, a.created_at
      FROM active_storage_attachments a
      JOIN active_storage_blobs b ON b.id = a.blob_id
      JOIN lote_fotos f ON f.lote_id = a.record_id AND f.created_at = b.created_at
      WHERE a.record_type = 'Lote' AND a.name = 'fotos'
    SQL
    execute "DELETE FROM active_storage_attachments WHERE record_type = 'Lote' AND name = 'fotos'"
  end

  def down
    execute <<~SQL
      INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
      SELECT 'fotos', 'Lote', f.lote_id, a.blob_id, a.created_at
      FROM active_storage_attachments a JOIN lote_fotos f ON f.id = a.record_id
      WHERE a.record_type = 'LoteFoto' AND a.name = 'imagen'
    SQL
    execute "DELETE FROM active_storage_attachments WHERE record_type = 'LoteFoto'"
    drop_table :lote_fotos
  end
end
