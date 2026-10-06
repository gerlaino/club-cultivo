module Medico
  class TurnosController < BaseController
    # GET /api/medico/turnos
    def index
      turnos = club.turnos
                   .del_medico(current_user.id)
                   .includes(:paciente)
                   .order(:fecha_hora)

      render json: turnos.map { |t| serialize(t) }
    end

    # POST /api/medico/turnos
    def create
      # Sólo con sus pacientes: el id viene del navegador (6-oct-2026).
      return paciente_ajeno unless paciente_visible?(turno_params[:paciente_id])

      turno = club.turnos.new(turno_params.merge(medico_id: current_user.id))
      if turno.save
        render json: serialize(turno), status: :created
      else
        render json: { errors: turno.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/medico/turnos/:id
    def update
      turno = club.turnos.del_medico(current_user.id).find(params[:id])
      return paciente_ajeno if turno_params.key?(:paciente_id) && !paciente_visible?(turno_params[:paciente_id])

      if turno.update(turno_params)
        render json: serialize(turno)
      else
        render json: { errors: turno.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/medico/turnos/:id
    def destroy
      turno = club.turnos.del_medico(current_user.id).find(params[:id])
      if turno.realizado?
        return render json: { error: 'No se puede eliminar un turno ya realizado' }, status: :unprocessable_entity
      end
      # Cancelar = flip de estado; no re-validamos el turno entero (un médico/paciente
      # con referencia colgada no debe impedir cancelar). El guard de realizado? ya está.
      turno.update_columns(estado: 'cancelado', updated_at: Time.current)
      turno.transmitir_cambio # `update_columns` se saltea los callbacks: las agendas abiertas, a mano
      head :no_content
    end

    # PATCH /api/medico/turnos/:id/visto — «Lo vi»: el médico confirma que vio el turno que le
    # dio administración (6-oct-2026). Administración lo ve como «Visto».
    def visto
      turno = club.turnos.del_medico(current_user.id).find(params[:id])
      turno.marcar_visto!
      render json: serialize(turno)
    end

    private

    def paciente_visible?(id)
      id.present? && pacientes_visibles.exists?(id: id)
    end

    def paciente_ajeno
      render json: { errors: ['Ese paciente no está vinculado a vos.'] }, status: :unprocessable_entity
    end

    def turno_params
      params.require(:turno).permit(:paciente_id, :fecha_hora, :duracion_minutos,
                                    :tipo, :estado, :motivo, :notas_post)
    end

    def serialize(t)
      {
        id:                t.id,
        paciente_id:       t.paciente_id,
        paciente_nombre:   t.paciente&.nombre_completo,
        fecha_hora:        t.fecha_hora,
        duracion_minutos:  t.duracion_minutos,
        tipo:              t.tipo,
        estado:            t.estado,
        motivo:            t.motivo,
        notas_post:        t.notas_post,
        paciente_apodo:    t.paciente&.apodo,
        visto_at:          t.visto_at,
      }
    end
  end
end
