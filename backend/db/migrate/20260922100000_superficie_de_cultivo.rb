# Los metros cuadrados de cultivo (22-sep-2026, Germán).
#
# El rendimiento de una genética se declara en **g/m²** —que es como lo publican los bancos y
# como se compara de verdad: el techo lo pone la luz sobre el metro, no la cantidad de plantas—
# y hasta ahora no había con qué dividir los gramos cosechados. La superficie va en la SALA
# («la carpa es 1 m²») y, opcionalmente, en el LOTE («este lote ocupa 0,6 m²»), porque en una
# sala pueden convivir varios lotes y repartir por plantas sería inventar.
#
# Las dos son OPCIONALES a propósito: sin metros se sigue creando salas y lotes y se siguen
# sacando informes; lo único que pasa es que el g/m² no se puede calcular y la pantalla lo dice.
class SuperficieDeCultivo < ActiveRecord::Migration[7.2]
  def change
    add_column :salas, :m2,           :decimal, precision: 8, scale: 2
    add_column :lotes, :m2_ocupados,  :decimal, precision: 8, scale: 2
  end
end
