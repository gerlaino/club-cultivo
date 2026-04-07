module Public
  class GeneticasController < BaseController
    def index
      geneticas = current_club.geneticas.visibles_web
      render json: { data: geneticas.map { |g| genetica_json(g) } }
    end

    def show
      genetica = current_club.geneticas.visibles_web.find_by(id: params[:id])
      return render json: { error: 'Genética no encontrada' }, status: :not_found unless genetica
      render json: { data: genetica_json(genetica, detailed: true) }
    end

    private

    def genetica_json(genetica, detailed: false)
      base = {
        id:          genetica.id,
        nombre:      genetica.nombre,
        tipo:        genetica.tipo,
        thc:         genetica.thc,
        cbd:         genetica.cbd,
        disponible:  genetica.disponible,
        visible_web: genetica.visible_web,
        registrada_inase: genetica.registrada_inase,
        criador:     genetica.criador,
        origen:      genetica.origen,
        terpenos:    genetica.terpenos,
        tiempo_floracion: genetica.tiempo_floracion,
        fotos_urls:  genetica.fotos.attached? ? genetica.fotos.map { |f| url_for(f) } : []
      }
      base[:descripcion] = genetica.descripcion if detailed
      base
    end
  end
end