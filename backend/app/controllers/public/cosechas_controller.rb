module Public
  class CosechasController < BaseController
    def show_qr
      lote = Lote.joins(:club)
                 .where(codigo_qr_cosecha: params[:codigo_qr])
                 .first

      return render json: { error: 'Cosecha no encontrada' }, status: :not_found unless lote

      club = lote.club

      render json: {
        id:              lote.id,
        codigo:          lote.codigo,
        codigo_qr:       lote.codigo_qr_cosecha,
        estado:          lote.estado,
        plants_count:    lote.plants_count,
        genetica:        lote.genetica ? { id: lote.genetica.id, nombre: lote.genetica.nombre } : nil,
        club_nombre:     club.name,
        club_logo:       club.logo.attached? ? url_for(club.logo) : nil,
      }
    end
  end
end
