# De qué arqueo del mostrador salió un ajuste de inventario.
#
# El informe de Pérdidas ya contaba estos gramos —caen en "Ajustes de inventario en menos"— pero
# mezclados con cualquier otra corrección de stock: el admin veía "61 g" y no tenía forma de saber
# que eran del mostrador. Separarlos por el texto de las notas ("Arqueo del mostrador…") es
# exactamente el tipo de regla que se rompe la primera vez que alguien toca el mensaje.
class AddTurnoMostradorAStockMovimientos < ActiveRecord::Migration[7.2]
  def change
    # `to_table` explícito: el inflector pluralizaba "turno_mostrador" como "turno_mostradors".
    add_reference :stock_movimientos, :turno_mostrador, null: true, index: true,
                  foreign_key: { to_table: :turno_mostradores }
  end
end
