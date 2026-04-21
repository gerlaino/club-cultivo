module Public
  class PlantasController < BaseController
    def show_qr
      plant = Plant.joins(lote: :club)
                   .where(codigo_qr: params[:codigo_qr])
                   .first

      return render json: { error: 'Planta no encontrada' }, status: :not_found unless plant

      club = plant.lote.club

      render json: {
        id:          plant.id,
        nombre:      plant.nombre,
        codigo_qr:   plant.codigo_qr,
        estado:      plant.state,
        lote: {
          id:     plant.lote.id,
          codigo: plant.lote.codigo,
        },
        club_nombre: club.name,
        club_logo:   club.logo.attached? ? url_for(club.logo) : nil,
      }
    end
  end
end