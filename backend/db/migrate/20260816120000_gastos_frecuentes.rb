# Marcar un gasto como FRECUENTE, para volver a cargarlo sin tipearlo de nuevo.
#
# Ya existía la detección automática (`movimientos_contables#recurrentes`: seis meses de
# historial, agrupando por tipo+categoría+sede+descripción normalizada). Adivinar sirve para
# proponer, pero no para buscar: el alquiler aparece recién después de dos meses cargándolo a
# mano, y lo que se paga cada dos meses no aparece nunca.
#
# La marca es explícita y del usuario: él sabe cuáles va a repetir el primer día. La detección
# se conserva — son dos cosas distintas y no se estorban.
#
# No es una tabla aparte a propósito: un "gasto frecuente" no es una entidad, es un movimiento
# real que además sirve de molde. Una tabla de plantillas se desincroniza del movimiento que la
# originó (cambia el proveedor, cambia la categoría) y hay que mantener las dos.
class GastosFrecuentes < ActiveRecord::Migration[7.2]
  def change
    add_column :movimientos_contables, :frecuente, :boolean, null: false, default: false

    # El listado pide "los frecuentes de esta organización, los más recientes primero".
    add_index :movimientos_contables, %i[club_id frecuente fecha],
              where: 'frecuente', name: 'index_movimientos_frecuentes'
  end
end
