# CUÁNDO SALIÓ LA PLATA, que no es cuándo se compró.
#
# `fecha` es la del gasto: el día que se compró y la mercadería entró al depósito, y ahí se queda
# —el egreso se reconoce al comprar, esté pagado o no—. Un gasto que quedó «pendiente de pago» se
# saldaba marcando `pagado: true` y nada más, así que no había forma de saber cuándo se pagó: un
# gasto de agosto pagado en septiembre salía de la caja en agosto.
#
# NULLABLE a propósito, por el mismo motivo que `stock_movimientos.fecha`: entre que corre la
# migración y termina de deployar, el código viejo sigue insertando sin la columna. El modelo la
# completa al marcar pagado, y el backfill deja lo ya pagado con la fecha del gasto —lo único que
# se sabe de esos—.
class AddFechaPagoAMovimientosContables < ActiveRecord::Migration[7.2]
  def up
    add_column :movimientos_contables, :fecha_pago, :date
    execute 'UPDATE movimientos_contables SET fecha_pago = fecha WHERE pagado = TRUE AND fecha_pago IS NULL'
  end

  def down
    remove_column :movimientos_contables, :fecha_pago
  end
end
