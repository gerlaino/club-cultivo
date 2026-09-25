# El análisis de laboratorio del suelo de una cama (ver `AnalisisSuelo`): valores y/o el PDF.
class AnalisisSueloController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :autorizar!
  before_action :set_cama

  def index
    render json: @cama.analisis_suelo.map { |a| CamaSerializer.analisis(a) }
  end

  def create
    a = @cama.analisis_suelo.new(analisis_params.merge(club: @cama.club, user: current_user))
    a.archivo.attach(params[:archivo]) if params[:archivo].present?
    if a.save
      render json: CamaSerializer.analisis(a), status: :created
    else
      render json: { errors: a.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    return render json: { error: 'Solo un administrador puede borrar análisis' }, status: :forbidden unless current_user.admin?
    @cama.analisis_suelo.find(params[:id]).destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Análisis no encontrado' }, status: :not_found
  end

  private

  def autorizar!
    return if %w[admin supervisor cultivador].include?(current_user.role)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def set_cama
    @cama = current_user.club.camas.al_alcance_de(current_user).find(params[:cama_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Cama no encontrada' }, status: :not_found
  end

  def analisis_params
    params.require(:analisis).permit(:fecha, :laboratorio, :notas, *AnalisisSuelo::VALORES.map(&:to_sym))
  end
end
