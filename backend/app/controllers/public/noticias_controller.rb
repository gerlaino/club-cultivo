module Public
  class NoticiasController < BaseController
    def index
      noticias = current_club.noticias.para_web.limit(20)

      render json: {
        data: noticias.map { |n| noticia_json(n) }
      }
    end

    def show
      noticia = current_club.noticias.para_web.find_by(id: params[:id])

      return render json: { error: 'Noticia no encontrada' }, status: :not_found unless noticia

      render json: { data: noticia_json(noticia, detailed: true) }
    end

    private

    def noticia_json(noticia, detailed: false)
      base = {
        id: noticia.id,
        titulo: noticia.titulo,
        publicada_at: noticia.publicada_at,
        cover_url: noticia.cover_image.attached? ? url_for(noticia.cover_image) : noticia.cover_url
      }

      if detailed
        base[:contenido] = noticia.contenido
      else
        base[:preview] = noticia.contenido.truncate(200)
      end

      base
    end
  end
end