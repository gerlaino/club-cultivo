module Bar
  # Tareas del cronograma de un evento (anidado bajo /bares/:bar_id/eventos/:evento_id/tareas).
  # Gestión: admin/supervisor. Sin efectos contables.
  class EventoTareasController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action -> { require_feature!(:eventos) }
    before_action :require_gestion
    before_action :set_evento
    before_action :set_tarea, only: [:update, :destroy]

    # POST .../tareas
    def create
      tarea = @evento.tareas.build(tarea_params.merge(club: current_user.club))
      if tarea.save
        render json: serialize(tarea), status: :created
      else
        render json: { errors: tarea.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH .../tareas/:id
    def update
      if @tarea.update(tarea_params)
        render json: serialize(@tarea)
      else
        render json: { errors: @tarea.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE .../tareas/:id — soft-delete
    def destroy
      @tarea.update!(deleted_by_id: current_user.id)
      @tarea.destroy
      head :no_content
    end

    private

    def set_evento
      @evento = current_user.club.bares.find(params[:bar_id]).eventos_bar.find(params[:evento_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Evento no encontrado' }, status: :not_found
    end

    def set_tarea
      @tarea = @evento.tareas.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Tarea no encontrada' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor].include?(current_user&.role)
    end

    def tarea_params
      params.require(:evento_bar_tarea).permit(:titulo, :hecha, :vence_el, :orden)
    end

    def serialize(t)
      { id: t.id, titulo: t.titulo, hecha: t.hecha, vence_el: t.vence_el, orden: t.orden }
    end
  end
end
