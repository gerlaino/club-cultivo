class ResyncLotePlantsCount < ActiveRecord::Migration[7.2]
  # Resincroniza plants_count con el conteo VIVO de plantas (no descartadas, no
  # eliminadas). Corrige el drift histórico: plantas descartadas no decrementaban el
  # contador, así que algunos lotes mostraban de más. Solo toca lotes que tienen
  # registros de planta (no toca lotes cuyo contador no tiene plantas asociadas).
  def up
    execute <<~SQL.squish
      UPDATE lotes SET plants_count = (
        SELECT COUNT(*) FROM plants
        WHERE plants.lote_id = lotes.id
          AND plants.deleted_at IS NULL
          AND plants.state <> 'descartada'
      )
      WHERE EXISTS (SELECT 1 FROM plants WHERE plants.lote_id = lotes.id)
    SQL
  end

  def down
    # No-op: no se puede restaurar el valor desincronizado anterior.
  end
end
