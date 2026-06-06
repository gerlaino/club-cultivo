class AmbienteChannel < ApplicationCable::Channel
  def subscribed
    sala_id = params[:sala_id].to_i
    return reject unless sala_id > 0
    # Verificar que el usuario tenga acceso a esta sala
    sala = current_user.club&.salas&.find_by(id: sala_id)
    return reject unless sala
    stream_from "ambiente_sala_#{sala_id}"
  end

  def unsubscribed; end
end
