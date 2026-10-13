# GET /ultimas_acciones?limite= — lo último que se hizo en el cultivo, para el inicio del
# autocultivo (`Autocultivo::UltimasAcciones`). Cada uno ve lo de sus lotes (`Lote.al_alcance_de`).
class UltimasAccionesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }

  ROLES = %w[admin supervisor cultivador].freeze

  def index
    return render json: { error: 'No autorizado' }, status: :forbidden unless ROLES.include?(current_user.role)

    render json: { acciones: Autocultivo::UltimasAcciones.new(usuario: current_user, limite: params[:limite] || 8).call }
  end
end
