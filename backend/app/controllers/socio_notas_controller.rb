# app/controllers/socio_notas_controller.rb
class SocioNotasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_socio, only: [:index, :create]

  # GET /pacientes/:paciente_id/notas
  def index
    notas = @paciente.notas.order(created_at: :desc)
    render json: { data: notas }
  end

  # POST /pacientes/:paciente_id/notas
  def create
    nota = @paciente.notas.build(nota_params)
    nota.user_id = current_user.id

    if nota.save
      render json: { data: nota }, status: :created
    else
      render json: { errors: nota.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /socio_notas/:id
  def destroy
    nota = SocioNota.joins(:paciente)
                    .where(pacientes: { club_id: current_user.club_id })
                    .find(params[:id])
    nota.destroy
    head :no_content
  end

  private

  def set_socio
    # Aseguramos que el paciente pertenezca al mismo club que el usuario
    @paciente = Paciente.for_club(current_user.club_id).find(params[:paciente_id])
  end

  def nota_params
    params.require(:nota).permit(:contenido)
  end
end



