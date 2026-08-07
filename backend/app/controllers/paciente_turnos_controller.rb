class PacienteTurnosController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }

  # GET /api/pacientes/:paciente_id/turnos
  def index
    paciente = club.pacientes.find(params[:paciente_id])
    turnos   = paciente.turnos
                       .includes(:medico)
                       .order(fecha_hora: :desc)

    render json: turnos.map { |t| serialize(t) }
  end

  private

  def club
    current_user.club
  end

  def serialize(t)
    {
      id:               t.id,
      paciente_id:      t.paciente_id,
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
