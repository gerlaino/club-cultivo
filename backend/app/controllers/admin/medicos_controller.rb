module Admin
  class MedicosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    # GET /api/admin/medicos
    # Lista todos los médicos del club con su disponibilidad resumida
    def index
      medicos = club.users.where(role: 'medico').order(:last_name, :first_name)
      render json: medicos.map { |m| serialize_medico(m) }
    end

    # GET /api/admin/medicos/:id/disponibilidad
    def disponibilidad
      medico = club.users.find(params[:id])
      slots  = medico.disponibilidad_medicos.where(club: club).activas.order(:dia_semana, :hora_inicio)
      render json: slots.map { |s| { id: s.id, dia_semana: s.dia_semana, hora_inicio: s.hora_inicio, hora_fin: s.hora_fin } }
    end

    # GET /api/admin/medicos/:id/turnos
    def turnos
      medico = club.users.find(params[:id])
      turnos = club.turnos
                   .del_medico(medico.id)
                   .includes(:paciente)
                   .order(:fecha_hora)

      render json: turnos.map { |t| serialize_turno(t) }
    end

    # POST /api/admin/medicos/:id/turnos
    def crear_turno
      medico  = club.users.find(params[:id])
      paciente = club.pacientes.find(turno_params[:paciente_id])

      turno = club.turnos.new(
        turno_params.merge(medico_id: medico.id)
      )

      if turno.save
        render json: serialize_turno(turno), status: :created
      else
        render json: { errors: turno.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def require_admin!
      render json: { error: 'No autorizado' }, status: :forbidden unless current_user.admin? || current_user.super_admin?
    end

    def club
      current_user.club
    end

    def turno_params
      params.require(:turno).permit(:paciente_id, :fecha_hora, :duracion_minutos, :tipo, :motivo)
    end

    def serialize_medico(m)
      {
        id:              m.id,
        nombre_completo: m.nombre_completo,
        first_name:      m.first_name,
        last_name:       m.last_name,
        email:           m.email,
        tiene_disponibilidad: m.disponibilidad_medicos.where(club: club).activas.exists?,
      }
    end

    def serialize_turno(t)
      {
        id:               t.id,
        paciente_id:      t.paciente_id,
        paciente_nombre:  t.paciente&.nombre_completo,
        fecha_hora:       t.fecha_hora,
        duracion_minutos: t.duracion_minutos,
        tipo:             t.tipo,
        estado:           t.estado,
        motivo:           t.motivo,
      }
    end
  end
end
