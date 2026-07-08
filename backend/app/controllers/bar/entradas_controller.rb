module Bar
  # Entradas vendidas de un evento. Listado y anulación (devolución). Gestión: admin/supervisor.
  # El check-in por QR vive en Capa 4.
  class EntradasController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :require_gestion
    before_action :set_evento

    # GET .../entradas
    def index
      entradas = @evento.entradas.includes(:evento_bar_tipo_entrada).order(created_at: :desc).limit(500)
      render json: entradas.map { |e| serialize(e) }
    end

    # DELETE .../entradas/:id — anula la entrada (no se borra: queda como 'anulada') y actualiza
    # el ingreso agregado de su tipo. Devuelve el cupo.
    def destroy
      entrada = @evento.entradas.find(params[:id])
      ActiveRecord::Base.transaction do
        entrada.update!(estado: 'anulada')
        entrada.evento_bar_tipo_entrada.sincronizar_ingreso!(current_user)
      end
      head :no_content
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Entrada no encontrada' }, status: :not_found
    end

    private

    def set_evento
      @evento = current_user.club.bares.find(params[:bar_id]).eventos_bar.find(params[:evento_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Evento no encontrado' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor].include?(current_user&.role)
    end

    def serialize(e)
      { id: e.id, codigo: e.codigo, comprador: e.comprador, precio_ars: e.precio_ars.to_f,
        estado: e.estado, tipo: e.evento_bar_tipo_entrada&.nombre, check_in_at: e.check_in_at,
        created_at: e.created_at }
    end
  end
end
