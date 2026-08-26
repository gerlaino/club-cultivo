# La caja de turno deja de ser exclusiva del bar.
#
# El mostrador de dispensa necesita exactamente el mismo flujo que ya tenía el Salón —el admin
# abre con un fondo, el dispensador confirma que está, y al final se arquea— y la mecánica ya
# estaba escrita y probada. Lo único que la ataba al bar era `bar_id NOT NULL`.
#
# Se generaliza a un PUNTO DE VENTA polimórfico: una `Barra` (el buffet) o una `Sede` (su
# mostrador de dispensa). Son cajas INDEPENDIENTES: cada punto abre, arquea y cierra la suya, y
# la plata nunca se mezcla. Lo que se comparte es el código, no el dinero.
#
# `bar_id` se conserva —lo usan las consultas del Salón y `Barra#caja_abierta`— pero pasa a ser
# opcional: en una caja de dispensario es NULL.
class GeneralizarCajaTurnoAPuntoDeVenta < ActiveRecord::Migration[7.2]
  def up
    add_column :caja_turnos, :punto_type, :string
    add_column :caja_turnos, :punto_id,   :bigint

    # Backfill ANTES de exigir nada: sin esto, toda caja del bar que ya existe queda sin dueño y
    # el modelo la da por inválida — incluidas las que están ABIERTAS ahora mismo.
    execute <<~SQL
      UPDATE caja_turnos SET punto_type = 'Barra', punto_id = bar_id WHERE bar_id IS NOT NULL
    SQL

    change_column_null :caja_turnos, :bar_id, true

    add_index :caja_turnos, [:punto_type, :punto_id],
              unique: true,
              where:  "estado IN ('abierta', 'pendiente_cierre')",
              name:   'index_caja_turnos_activa_por_punto'

    # Los cobros del turno se enganchan a la caja, igual que `bar_ventas.caja_turno_id`: es lo que
    # permite arquear el mostrador (fondo + lo cobrado en efectivo) sin adivinar por ventana de
    # tiempo, que se rompe apenas alguien abre la caja tarde o cierra al otro día.
    add_reference :cobros, :caja_turno, foreign_key: true, null: true, index: true
  end

  def down
    remove_reference :cobros, :caja_turno, foreign_key: true
    remove_index  :caja_turnos, name: 'index_caja_turnos_activa_por_punto'
    # Las cajas de dispensario no tienen bar: hay que sacarlas antes de volver a exigir bar_id.
    execute "DELETE FROM caja_turnos WHERE bar_id IS NULL"
    change_column_null :caja_turnos, :bar_id, false
    remove_column :caja_turnos, :punto_id
    remove_column :caja_turnos, :punto_type
  end
end
