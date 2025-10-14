# app/controllers/socio_notas_controller.rb
class SocioNotasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_socio, only: [:index, :create]

  # GET /socios/:socio_id/notas
  def index
    notas = @socio.notas.order(created_at: :desc)
    render json: { data: notas }
  end

  # POST /socios/:socio_id/notas
  def create
    nota = @socio.notas.build(nota_params)
    nota.user = current_user

    if nota.save
      render json: { data: nota }, status: :created
    else
      render json: { errors: nota.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /socio_notas/:id
  def destroy
    nota = SocioNota.find(params[:id])
    nota.destroy
    head :no_content
  end

  private

  def set_socio
    # Aseguramos que el socio pertenezca al mismo club que el usuario
    @socio = Socio.for_club(current_user.club_id).find(params[:socio_id])
  end

  def nota_params
    params.require(:nota).permit(:contenido)
  end
end



