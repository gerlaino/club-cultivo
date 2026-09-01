# En qué turno del mostrador ocurrió la dispensa.
#
# La imputación contra el ítem se resuelve sola (hay un solo turno abierto por mostrador), pero
# guardar el turno deja el rastro: al revisar una diferencia hay que poder ver qué se dispensó
# en ESE turno sin adivinar por ventana de tiempo, que se rompe apenas alguien cierra pasada la
# medianoche. Es lo mismo que ya hace `cobros.caja_turno_id` con la plata.
class AddTurnoMostradorADispensaciones < ActiveRecord::Migration[7.2]
  def change
    # `to_table` explícito: el inflector EN pluraliza "turno_mostrador" como "turno_mostradors"
    # y la FK apunta a una tabla que no existe.
    add_reference :dispensaciones, :turno_mostrador, null: true, index: true,
                  foreign_key: { to_table: :turno_mostradores }
  end
end
