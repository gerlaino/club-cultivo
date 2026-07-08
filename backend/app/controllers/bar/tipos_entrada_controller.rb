module Bar
  # Tipos de entrada de un evento + venta (POST :vender). Gestión: admin/supervisor.
  # (dispensador puede vender en puerta — se habilita en Capa 4; acá gestión.)
  class TiposEntradaController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :require_gestion
    before_action :set_evento
    before_action :set_tipo, only: [:update, :destroy, :vender]

    # POST .../tipos_entrada
    def create
      tipo = @evento.tipos_entrada.build(tipo_params.merge(club: current_user.club))
      if tipo.save
        render json: serialize(tipo), status: :created
      else
        render json: { errors: tipo.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH .../tipos_entrada/:id
    def update
      if @tipo.update(tipo_params)
        render json: serialize(@tipo)
      else
        render json: { errors: @tipo.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE .../tipos_entrada/:id — soft-delete (saca su ingreso agregado del libro vía entradas)
    def destroy
      @tipo.update!(deleted_by_id: current_user.id)
      @tipo.destroy
      head :no_content
    end

    # POST .../tipos_entrada/:id/vender  { cantidad, comprador? }
    def vender
      entradas = ::Bar::VenderEntradas.new(
        @tipo, current_user, cantidad: params[:cantidad], comprador: params[:comprador]
      ).call
      render json: serialize(@tipo).merge(vendidas_ahora: entradas.size), status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def set_evento
      @evento = current_user.club.bares.find(params[:bar_id]).eventos_bar.find(params[:evento_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Evento no encontrado' }, status: :not_found
    end

    def set_tipo
      @tipo = @evento.tipos_entrada.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Tipo de entrada no encontrado' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor].include?(current_user&.role)
    end

    def tipo_params
      params.require(:evento_bar_tipo_entrada).permit(:nombre, :precio_ars, :cupo, :orden, :activo)
    end

    def serialize(t)
      { id: t.id, nombre: t.nombre, precio_ars: t.precio_ars.to_f, cupo: t.cupo,
        vendidas: t.vendidas, disponibles: t.disponibles, agotado: t.agotado?,
        recaudado: t.recaudado, activo: t.activo }
    end
  end
end
