# Lo que le cambia AL PACIENTE, en vivo: hoy, su chat con la organización (mensaje nuevo, leído,
# «está escribiendo»). Mismo formato que `ClubChannel` (`{ recurso, accion, id, at }`) y sin
# datos: la pantalla re-pide lo suyo.
#
# El stream sale de la ficha de quien está conectado, nunca de un parámetro del cliente: un
# paciente no puede escuchar el canal de otro.
class PacienteChannel < ApplicationCable::Channel
  def self.stream(paciente_id) = "paciente_#{paciente_id}"

  def subscribed
    ficha = ficha_actual
    return reject unless ficha

    stream_from self.class.stream(ficha.id)
  end

  # El paciente está escribiendo: se le avisa a su organización (la bandeja y su ficha).
  def escribiendo(_data = nil)
    ficha = ficha_actual
    return unless ficha

    Transmite.emitir(ficha.club_id, recurso: 'mensajes', accion: 'escribiendo', id: ficha.id)
  end

  def unsubscribed; end

  private

  def ficha_actual
    return nil unless current_user&.paciente? && current_user.club_id

    ActsAsTenant.with_tenant(current_user.club) { Paciente.find_by(user_id: current_user.id) }
  end
end
