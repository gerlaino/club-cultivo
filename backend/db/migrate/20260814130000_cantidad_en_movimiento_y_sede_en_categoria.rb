# Dos cosas que el alta de un movimiento contable no sabía guardar:
#
# 1. CUÁNTO se compró y en qué unidad. La cantidad existía sólo dentro de `destino` —el bloque que
#    mete la compra en un depósito—, así que un gasto que NO entra al inventario no tenía dónde
#    decir "100.000 por 10 horas". Sin cantidad no hay costo unitario, que es el número con el que
#    se compara un proveedor contra otro y el que después alimenta el costo por lote.
#    Es dato del movimiento, no del inventario: por eso va acá y el destino lo REUSA en vez de
#    volver a preguntarlo.
#
# 2. De qué SEDE es una categoría. El sector (unidad de negocio) es el eje analítico y es
#    transversal; la sede es física. Una categoría como "Maceta" puede ser de una sede puntual
#    (la finca que produce) y no tener sentido en la otra. `sede_id` nulo = de toda la
#    organización, que es como se comportaban todas hasta hoy.
#
# El "va a depósito" que pide el alta de categoría NO lleva columna: ya lo dice `comportamiento`
# (general = no stockea; insumo/insumo_general/mercaderia = sí, y a cuál). Duplicarlo en un
# booleano sería un segundo lugar donde decir lo mismo, y el día que discrepen no hay forma de
# saber cuál manda.
class CantidadEnMovimientoYSedeEnCategoria < ActiveRecord::Migration[7.2]
  def change
    # 3 decimales: se compran 2,5 kg y 0,75 l. El monto sigue siendo el total, no el unitario.
    add_column :movimientos_contables, :cantidad, :decimal, precision: 12, scale: 3
    add_column :movimientos_contables, :unidad,   :string

    add_reference :categorias_contables, :sede, foreign_key: true, null: true, index: true
  end
end
