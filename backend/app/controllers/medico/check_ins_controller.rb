module Medico
  class CheckInsController < BaseController
    # POST /api/medico/check_ins
    def create
      paciente = club.pacientes.find(check_in_params[:paciente_id])
      check_in = paciente.check_ins.new(
        check_in_params.merge(club_id: club.id, via_registro: 'medico')
      )
      if check_in.save
        render json: serialize(check_in), status: :created
      else
        render json: { errors: check_in.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def check_in_params
      params.require(:check_in).permit(:paciente_id, :dispensacion_id,
                                       :escala_bienestar, :notas,
                                       sintomas: {})
    end

    def serialize(ci)
      {
        id:               ci.id,
        paciente_id:      ci.paciente_id,
        dispensacion_id:  ci.dispensacion_id,
        escala_bienestar: ci.escala_bienestar,
        sintomas:         ci.sintomas,
        notas:            ci.notas,
        via_registro:     ci.via_registro,
        fecha:            ci.created_at.to_date,
      }
    end
  end
end
