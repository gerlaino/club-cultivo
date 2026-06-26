class SoftDeleteSalasProcesoHuerfanas < ActiveRecord::Migration[7.2]
  # Limpieza one-time: el flujo viejo (Sala.find_or_create_proceso!) auto-creaba salas de
  # proceso post-cosecha ("Cosecha/Secado/Curado · Sede"). La unificación de estados las dejó
  # huérfanas (lotes con sala_id = NULL) pero el registro seguía existiendo y contaba en el
  # informe de sedes. Las soft-borramos (Sala es paranoid) SOLO si ningún lote las referencia,
  # para no arrastrar nada. Reversible vía deleted_at, sin disparar dependent: :destroy.
  def up
    execute <<~SQL
      UPDATE salas
         SET deleted_at = NOW()
       WHERE deleted_at IS NULL
         AND (kind IN ('cosecha','secado','curado') OR tipo IN ('cosecha','secado','curado'))
         AND id NOT IN (SELECT sala_id FROM lotes WHERE sala_id IS NOT NULL)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
