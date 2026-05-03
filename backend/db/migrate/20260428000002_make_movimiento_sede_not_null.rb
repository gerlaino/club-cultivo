class MakeMovimientoSedeNotNull < ActiveRecord::Migration[7.2]
  def up
    # Backfill: asignar la primera sede activa del club a movimientos sin sede
    execute <<~SQL
      UPDATE movimientos_contables mc
      SET sede_id = (
        SELECT s.id FROM sedes s
        WHERE s.club_id = mc.club_id AND s.activa = true
        ORDER BY s.id ASC
        LIMIT 1
      )
      WHERE mc.sede_id IS NULL
    SQL

    # Si quedó alguno sin sede (club sin sedes activas), asignar primera sede del club
    execute <<~SQL
      UPDATE movimientos_contables mc
      SET sede_id = (
        SELECT s.id FROM sedes s
        WHERE s.club_id = mc.club_id
        ORDER BY s.id ASC
        LIMIT 1
      )
      WHERE mc.sede_id IS NULL
    SQL

    change_column_null :movimientos_contables, :sede_id, false
    change_column :movimientos_contables, :sede_id, :bigint, null: false
  end

  def down
    change_column_null :movimientos_contables, :sede_id, true
  end
end
