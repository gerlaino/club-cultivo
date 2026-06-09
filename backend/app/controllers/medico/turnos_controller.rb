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
      if turno.update(turno_params)
        render json: serialize(turno)
      else
        render json: { errors: turno.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/medico/turnos/:id
    def destroy
      turno = club.turnos.del_medico(current_user.id).find(params[:id])
      turno.update!(estado: 'cancelado')
      head :no_content
    end

    private

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
      }
    end
  end
end
