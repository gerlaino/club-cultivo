# «Algo cambió en tu organización». Un solo canal por club, un solo formato de aviso
# (`Transmite`): `{ recurso, accion, id, sede_id, por, at }`. El frontend tiene un consumer y
# cada store se suscribe a su recurso y re-pide lo que muestra. Los canales viejos (stocks,
# alertas, ambiente) siguen para lo que ya los usa; lo nuevo entra por acá.
#
# Tenant: el stream sale de `current_user.club_id` (que para el super admin observando ya
# viene enmascarado), nunca de un parámetro del cliente.
class ClubChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user&.club_id
    stream_from "club_#{current_user.club_id}"
  end

  def unsubscribed; end
end
