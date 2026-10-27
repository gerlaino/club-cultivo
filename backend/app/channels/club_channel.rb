# «Algo cambió en tu organización». Un solo canal por club, un solo formato de aviso
# (`Transmite`): `{ recurso, accion, id, sede_id, por, at }`. El frontend tiene un consumer y
# cada store se suscribe a su recurso y re-pide lo que muestra. Los canales viejos (stocks,
# alertas, ambiente) siguen para lo que ya los usa; lo nuevo entra por acá.
#
# Tenant: el stream sale de `current_user.club_id` (que para el super admin observando ya
# viene enmascarado), nunca de un parámetro del cliente.
#
# El PACIENTE no escucha este canal (27-oct-2026): le llegaba el aviso de cada cosa que hacía el
# equipo —qué recurso, qué número y quién—. Lo suyo le llega por `PacienteChannel`.
class ClubChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user&.club_id && !current_user.paciente?
    stream_from "club_#{current_user.club_id}"
  end

  # «Está escribiendo…» en el chat con un paciente: se le avisa SÓLO a ese paciente, y sólo si es
  # de esta organización y quien escribe atiende el chat.
  def escribiendo(data)
    return unless ConversacionPaciente::ROLES_ATIENDEN.include?(current_user.role)

    paciente_id = data['paciente_id'].to_i
    existe = ActsAsTenant.with_tenant(current_user.club) { Paciente.exists?(id: paciente_id) }
    return unless existe

    ActionCable.server.broadcast(PacienteChannel.stream(paciente_id), {
      recurso: 'mensajes', accion: 'escribiendo', id: paciente_id, por: current_user.first_name,
      at: Time.current.iso8601(3),
    })
  end

  def unsubscribed; end
end
