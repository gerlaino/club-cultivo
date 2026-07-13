class AmbienteChannel < ApplicationCable::Channel
  def subscribed
    sala_id = params[:sala_id].to_i
    return reject unless sala_id > 0
    # Verificar que el usuario tenga acceso a esta sala. Los channels no pasan por
    # ApplicationController, así que no hay tenant fijado → con require_tenant=true el
    # query a Sala explotaría. Lo fijamos explícito al club del usuario.
    sala = ActsAsTenant.with_tenant(current_user.club) do
      current_user.club&.salas&.find_by(id: sala_id)
    end
    return reject unless sala
    stream_from "ambiente_sala_#{sala_id}"
  end

  def unsubscribed; end
end
