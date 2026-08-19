module Portal
  class GeneticasController < BaseController
    def index
      geneticas = current_club.geneticas.visibles_paciente
      render json: { data: geneticas.map { |g| genetica_json(g) } }
    end

    # Acepta id o slug: los enlaces del catálogo mandan el id y los QR viejos, el slug.
    def show
      genetica = current_club.geneticas.visibles_paciente.find_by(slug: params[:id]) ||
                 current_club.geneticas.visibles_paciente.find_by(id: params[:id])
      return render json: { error: 'Genética no encontrada o no publicada' }, status: :not_found unless genetica
      render json: { data: genetica_json(genetica, detailed: true) }
    end

    private

    def genetica_json(genetica, detailed: false)
      base = {
        id:               genetica.id,
        slug:             genetica.slug,
        nombre:           genetica.nombre,
        tipo:             genetica.tipo,
        thc:              genetica.thc,
        cbd:              genetica.cbd,
        registrada_inase: genetica.registrada_inase,
        criador:          genetica.criador,
        origen:           genetica.origen,
        terpenos:         genetica.terpenos,
        tiempo_floracion: genetica.tiempo_floracion,
        dificultad:       genetica.dificultad,
        fotos_urls:       genetica.fotos.attached? ? genetica.fotos.map { |f| url_for(f) } : [],
      }
      base[:descripcion] = genetica.descripcion if detailed
      base
    end
  end
end