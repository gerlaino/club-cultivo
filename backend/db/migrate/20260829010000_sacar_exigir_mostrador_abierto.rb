# El mostrador NO es una perilla que se prende: es dónde opera el dispensador.
#
# Se había agregado `clubs.exigir_mostrador_abierto` por cautela de deploy —para que ninguna
# organización se quedara sin poder dispensar el día que saliera—, pero eso convertía la forma de
# dispensar en una opción, y una organización con la suite de Producción y dispensa que lo
# tuviera apagado quedaba con la pantalla del mostrador andando y sin ningún control detrás: lo
# peor de los dos mundos.
#
# Toda organización que dispensa lo hace desde su mostrador, y punto. La transición del primer
# día la resuelve el mensaje —"El mostrador está cerrado: abrilo antes de dispensar"— más el link
# al tope del menú del dispensador, no una columna que después nadie sabe para qué está.
class SacarExigirMostradorAbierto < ActiveRecord::Migration[7.2]
  def change
    remove_column :clubs, :exigir_mostrador_abierto, :boolean, null: false, default: false
  end
end
