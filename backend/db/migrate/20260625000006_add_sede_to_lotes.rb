class AddSedeToLotes < ActiveRecord::Migration[7.2]
  # Desacopla el lote de la sala: el lote tiene su propia sede. Las salas pasan a ser
  # solo de cultivo (vegetativo/floración); un lote post-cosecha no tiene sala
  # (sala_id = nil) pero conserva su sede. Backfill desde la sala actual.
  def up
    add_reference :lotes, :sede, foreign_key: true, null: true

    # Backfill: sede del lote = sede de su sala actual (o de la sala vía sede).
    execute <<~SQL
      UPDATE lotes
      SET sede_id = salas.sede_id
      FROM salas
      WHERE lotes.sala_id = salas.id AND lotes.sede_id IS NULL
    SQL

    # Post-cosecha: sin sala (se ven por estado en Cosecha/Manicura).
    execute <<~SQL
      UPDATE lotes
      SET sala_id = NULL
      WHERE estado IN ('cosecha','en_manicura','manicura_pendiente','curado','finalizado')
    SQL
  end

  def down
    remove_reference :lotes, :sede
  end
end
