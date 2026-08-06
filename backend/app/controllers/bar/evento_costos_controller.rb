module Bar
  # Costos/proveedores de un evento (anidado bajo /bares/:bar_id/eventos/:evento_id/costos).
  # Al marcar/desmarcar "pagado", el modelo sincroniza el egreso en el libro. Gestión: admin/supervisor.
  class EventoCostosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action -> { require_feature!(:eventos) }
    before_action :require_gestion
    before_action :set_evento
    before_action :set_costo, only: [:update, :destroy]

    # POST .../costos
    def create
      costo = @evento.costos.build(costo_params.merge(club: current_user.club, created_by: current_user))
      if costo.save
        render json: serialize(costo), status: :created
      else
        render json: { errors: costo.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH .../costos/:id
    def update
      if @costo.update(costo_params)
        render json: serialize(@costo)
      else
        render json: { errors: @costo.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE .../costos/:id — soft-delete; el modelo saca el egreso del libro.
    def destroy
      @costo.update!(deleted_by_id: current_user.id)
      @costo.destroy
      head :no_content
    end

    private

    def set_evento
      @evento = current_user.club.bares.find(params[:bar_id]).eventos_bar.find(params[:evento_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Evento no encontrado' }, status: :not_found
    end

    def set_costo
      @costo = @evento.costos.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Costo no encontrado' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor].include?(current_user&.role)
    end

    def costo_params
      params.require(:evento_bar_costo).permit(:concepto, :proveedor, :monto_ars, :pagado, :fecha)
    end

    def serialize(c)
      { id: c.id, concepto: c.concepto, proveedor: c.proveedor, monto_ars: c.monto_ars.to_f,
        pagado: c.pagado, fecha: c.fecha }
    end
  end
end
