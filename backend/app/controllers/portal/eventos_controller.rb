module Portal
  class EventosController < BaseController
    def index
      eventos = if params[:pasados] == 'true'
                  current_club.eventos.activos.pasados.ordenados
                else
                  current_club.eventos.para_web
                end

      render json: {
        data: eventos.map { |e| evento_json(e) }
      }
    end

    # POST /portal/eventos/:id/asistencia — «Asistiré». DELETE — ya no va.
    def asistir
      evento = current_club.eventos.activos.proximos.find_by(id: params[:id])
      return render json: { error: 'Ese evento ya pasó o no existe.' }, status: :not_found unless evento && ficha

      AsistenciaEvento.find_or_create_by!(evento: evento, paciente: ficha) { |a| a.club = current_club }
      render json: { data: evento_json(evento) }
    end

    def no_asistir
      evento = current_club.eventos.activos.find_by(id: params[:id])
      return render json: { error: 'Evento no encontrado' }, status: :not_found unless evento && ficha

      AsistenciaEvento.where(evento: evento, paciente: ficha).destroy_all
      render json: { data: evento_json(evento) }
    end

    def show
      evento = current_club.eventos.activos.find_by(id: params[:id])

      return render json: { error: 'Evento no encontrado' }, status: :not_found unless evento

      render json: { data: evento_json(evento, detailed: true) }
    end

    private

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    def evento_json(evento, detailed: false)
      base = {
        id: evento.id,
        titulo: evento.titulo,
        fecha_inicio: evento.fecha_inicio,
        fecha_fin: evento.fecha_fin,
        lugar: evento.lugar,
        imagenes_urls: evento.imagenes.attached? ? evento.imagenes.map { |i| url_for(i) } : [],
        # Si él va. Cuántos van NO: es de la organización (y en un evento chico, dice quiénes).
        asistire: ficha ? evento.asistencias.exists?(paciente_id: ficha.id) : false,
      }

      if detailed
        base[:descripcion] = evento.descripcion
      end

      base
    end
  end
end