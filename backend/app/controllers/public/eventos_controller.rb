module Public
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

    def show
      evento = current_club.eventos.activos.find_by(id: params[:id])

      return render json: { error: 'Evento no encontrado' }, status: :not_found unless evento

      render json: { data: evento_json(evento, detailed: true) }
    end

    private

    def evento_json(evento, detailed: false)
      base = {
        id: evento.id,
        titulo: evento.titulo,
        fecha_inicio: evento.fecha_inicio,
        fecha_fin: evento.fecha_fin,
        lugar: evento.lugar,
        imagenes_urls: evento.imagenes.attached? ? evento.imagenes.map { |i| url_for(i) } : []
      }

      if detailed
        base[:descripcion] = evento.descripcion
      end

      base
    end
  end
end