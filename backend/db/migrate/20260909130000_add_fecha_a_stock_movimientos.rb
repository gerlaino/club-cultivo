# CUÁNDO PASÓ, que no es lo mismo que cuándo se cargó.
#
# El movimiento se fechaba con `created_at`, o sea el momento en que alguien se sienta con la
# computadora. Cerrar un stock el jueves y anotarlo el lunes lo ponía en el lunes: el informe de
# Pérdidas mostraba la merma en la semana equivocada. Es el mismo motivo por el que una
# dispensación tiene `fecha_dispensacion` aparte de su `created_at` — una carga retroactiva es
# legítima y bloquearla dejaría afuera el trabajo de poner la historia al día.
#
# Queda NULLABLE a propósito: entre que corre esta migración y termina de deployar el código
# nuevo, el código viejo sigue insertando sin `fecha`. El modelo la completa siempre, y el
# backfill deja los años de historia con la fecha que corresponde.
class AddFechaAStockMovimientos < ActiveRecord::Migration[7.2]
  def up
    add_column :stock_movimientos, :fecha, :date
    execute 'UPDATE stock_movimientos SET fecha = created_at::date WHERE fecha IS NULL'
    add_index :stock_movimientos, :fecha
  end

  def down
    remove_index :stock_movimientos, :fecha
    remove_column :stock_movimientos, :fecha
  end
end
