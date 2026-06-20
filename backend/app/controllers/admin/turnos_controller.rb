module Admin
  class TurnosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    # PATCH /api/admin/turnos/:id
    def update
      turno = club.turnos.find(params[:id])
      if turno.update(turno_params)
        render json: serialize(turno)
      else
        render json: { errors: turno.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/admin/turnos/:id
    def destroy
      turno = club.turnos.find(params[:id])
      if turno.realizado?
        return render json: { error: 'No se puede eliminar un turno ya realizado' }, status: :unprocessable_entity
      end
      # Cancelar = flip de estado; no re-validamos el turno entero (un médico/paciente
      # con referencia colgada no debe impedir cancelar). El guard de realizado? ya está.
      turno.update_columns(estado: 'cancelado', updated_at: Time.current)
      head :no_content
    end

    private

    def require_admin!
      render json: { error: 'No autorizado' }, status: :forbidden unless current_user.admin? || current_user.super_admin?
    end

    def club
      current_user.club
    end

    def turno_params
      params.require(:turno).permit(:fecha_hora, :duracion_minutos, :tipo, :estado, :motivo, :notas_post)
    end

    def serialize(t)
      {
        id:               t.id,
        paciente_id:      t.paciente_id,
        paciente_nombre:  t.paciente&.nombre_completo,
        medico_id:        t.medico_id,
        medico_nombre:    t.medico&.nombre_completo,
        fecha_hora:       t.fecha_hora,
        duracion_minutos: t.duracion_minutos,
        tipo:             t.tipo,
        estado:           t.estado,
        motivo:           t.motivo,
      }
    end
  end
end
