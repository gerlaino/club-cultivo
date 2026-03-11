module Public
  class GaleriaController < BaseController
    def index
      geneticas = current_club.geneticas.activas.includes(fotos_attachments: :blob)

      fotos = []
      geneticas.each do |genetica|
        genetica.fotos.each do |foto|
          fotos << {
            id: foto.id,
            url: url_for(foto),
            genetica: {
              id: genetica.id,
              nombre: genetica.nombre
            }
          }
        end
      end

      render json: { data: fotos }
    end
  end
end