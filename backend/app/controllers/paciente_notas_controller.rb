class PacienteNotasController < ApplicationController
  before_action :authenticate_user!
  before_action :check_notas_role!
  before_action :set_paciente, only: [:index, :create]

  def index
    notas = @paciente.notas.order(created_at: :desc)
    render json: { data: notas }
  end

  def create
    nota = @paciente.notas.build(nota_params)
    nota.created_by = current_user

    if nota.save
      render json: { data: nota }, status: :created
    else
      render json: { errors: nota.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    nota = PacienteNota.joins(:paciente)
                       .where(pacientes: { club_id: current_user.club_id })
                       .find(params[:id])
    nota.destroy
    head :no_content
  end

  private

  def check_notas_role!
    blocked = %w[dispensador delivery]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def set_paciente
    @paciente = Paciente.for_club(current_user.club_id).find(params[:paciente_id] || params[:socio_id])
  end

  def nota_params
    params.require(:nota).permit(:contenido)
  end
end
