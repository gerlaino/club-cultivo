# Los médicos que atienden a un paciente (Javi y Germán, 6-oct-2026). Administración vincula y
# desvincula desde la ficha; el médico ve sólo a sus vinculados (`PacientePolicy::Scope`).
# Además se vincula solo al darle un turno y cuando el médico lo da de alta.
class PacienteMedicosController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:medico) }
  before_action :require_admin!, only: %i[create destroy]
  before_action :set_paciente

  # GET /pacientes/:paciente_id/medicos
  def index
    render json: @paciente.medico_pacientes.includes(:medico).map { |v| serialize(v) }
  end

  # POST /pacientes/:paciente_id/medicos  { medico_id }
  def create
    medico = current_user.club.users.where(role: 'medico').find_by(id: params[:medico_id])
    return render json: { error: 'Médico no encontrado' }, status: :not_found unless medico

    vinculo = MedicoPaciente.vincular!(medico: medico, paciente: @paciente, por: current_user)
    # Tener médico es tener seguimiento médico: si no, el médico no lo vería igual.
    @paciente.update!(con_seguimiento_medico: true, updated_by: current_user) unless @paciente.con_seguimiento_medico
    render json: serialize(vinculo), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  # DELETE /pacientes/:paciente_id/medicos/:id  (id = el del médico)
  def destroy
    @paciente.medico_pacientes.where(medico_id: params[:id]).destroy_all
    head :no_content
  end

  private

  def require_admin!
    return if current_user.admin? || current_user.super_admin?
    render json: { error: 'Sólo administración vincula médicos.' }, status: :forbidden
  end

  def set_paciente
    @paciente = pacientes_visibles.find(params[:paciente_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def serialize(v)
    { medico_id: v.medico_id, nombre: v.medico&.nombre_completo, desde: v.created_at }
  end
end
