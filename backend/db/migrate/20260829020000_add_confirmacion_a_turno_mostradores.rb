# La ENTREGA del mostrador: el admin lo carga y el que atiende confirma que lo recibió.
#
# No es el relevo que descartamos —ahí la misma persona contaba dos veces lo que ella misma había
# dejado, y termina en un botón que nadie mira—. Esto son DOS personas: el admin declara "puse
# 300 g sobre la mesa" y el que atiende dice "sí, están".
#
# Para qué sirve: para que el arqueo del cierre compare contra lo que HABÍA de verdad. Sin la
# recepción, la diferencia de la noche mezcla dos cosas distintas —lo que se consumió atendiendo
# y lo que nunca estuvo— y deja de medir nada. Es la misma mecánica de la caja de plata
# (`apertura_confirmada_por`) y por el mismo motivo.
class AddConfirmacionATurnoMostradores < ActiveRecord::Migration[7.2]
  def change
    add_reference :turno_mostradores, :confirmado_por, foreign_key: { to_table: :users }
    add_column    :turno_mostradores, :confirmado_at, :datetime
  end
end
