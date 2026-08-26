# Lo que pasa en la caja tiene que llegar al libro, y poder volver a la caja.
#
# Hasta ahora la caja de turno vivía sola: el fondo, lo cobrado y la diferencia de arqueo se
# guardaban en `caja_turnos` y de ahí no salían. Dos consecuencias:
#
#   · Un FALTANTE de arqueo es una pérdida real del club y no aparecía en ningún informe. Se veía
#     en el historial de cierres y ahí moría.
#   · No había forma de SACAR efectivo del cajón durante el turno (pagar un flete, un retiro).
#     Cualquier salida se leía después como faltante, sin lugar donde explicarla.
#
# Con `caja_turno_id` en los movimientos, las dos cosas son asientos normales —cuentan en el P&L
# como cualquier gasto— y además quedan atadas al turno que las generó, así el arqueo puede
# restarlas de lo esperado y el cierre se explica solo.
#
# El FONDO DE APERTURA sigue sin asiento, a propósito: no es ingreso ni egreso, es plata del club
# que cambia de lugar. Asentarlo diría que la organización ganó $10.000 por poner cambio.
class AtarMovimientosContablesALaCaja < ActiveRecord::Migration[7.2]
  def change
    add_reference :movimientos_contables, :caja_turno, foreign_key: true, null: true, index: true
  end
end
