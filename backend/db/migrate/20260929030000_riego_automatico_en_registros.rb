# Un riego que hizo un aparato (el ESP32 que maneja la bomba) queda en el lote como cualquier
# riego: un registro con la tarea «riego» y los litros. Ese registro no tiene una persona detrás,
# así que el autor pasa a ser opcional y se guarda qué dispositivo lo hizo (Germán, 29-sep-2026:
# «Automático» antes que firmarlo a nombre de un admin que no regó).
class RiegoAutomaticoEnRegistros < ActiveRecord::Migration[7.2]
  def change
    change_column_null :registros_ambientales, :user_id, true
    add_reference :registros_ambientales, :dispositivo, foreign_key: true, null: true, index: true
  end
end
