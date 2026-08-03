# Desprender parte de un lote: 20 esquejes que prenden, 10 van a maceta de 3 L y 10 a 5 L. Desde
# ese momento NO son el mismo grupo —riego, frecuencia y trasplante distintos, y la alerta de raíz
# enrollada da distinto para cada mitad—, así que dejan de caber en un lote con un solo
# `tamanio_maceta`: el dato le mentiría a la mitad de las plantas.
#
# CONTABILIDAD. El libro es la fuente de verdad y `CostoLote` se DERIVA de él
# (`CostoDesdeLibroService`), así que partir el CostoLote a mano no sirve: el próximo movimiento lo
# recalcularía y lo pisaría. Y partir los asientos del libro sería peor —un gasto real de $10.000
# no son dos de $5.000: no hay dos facturas—.
#
# Lo que se hace es lo que hace la contabilidad de costos conjuntos: el gasto queda entero y con su
# lote original en el libro, y el COSTEO reparte lo común. Al desprender se congela cuánto se llevó
# el hijo (`costo_heredado_ars`) y cuánto cedió el padre (`costo_cedido_ars`), y el servicio de
# costos los suma/resta. Se congela en pesos, y no como proporción a recalcular, para que el número
# no se mueva solo cuando después cambien las plantas o se carguen gastos nuevos: lo que se llevó
# es lo que se llevó el día que se separó, y queda auditable.
class DesprenderLotes < ActiveRecord::Migration[7.2]
  def change
    add_reference :lotes, :lote_origen, null: true, foreign_key: { to_table: :lotes }
    add_column    :lotes, :split_at, :datetime
    add_column    :lotes, :costo_heredado_ars, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column    :lotes, :costo_cedido_ars,   :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
