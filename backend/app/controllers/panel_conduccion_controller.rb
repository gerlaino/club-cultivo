# EL PANEL DE CONDUCCIÓN: el inicio del administrador de una organización (12-oct-2026). El cálculo
# vive en `Panel::Conduccion` y el detalle de un cierre en `Panel::DetalleCierre`; acá sólo se
# autoriza y se filtra. Sólo admin: es la vista de quien conduce, con plata y con personas.
class PanelConduccionController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :no_en_autocultivo!

  # GET /panel_conduccion?sede_id=&periodo=hoy|semana|mes
  def show
    render json: Panel::Conduccion.new(club: current_user.club, sede_id: params[:sede_id], periodo: params[:periodo]).call
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sede no encontrada' }, status: :not_found
  end

  # GET /panel_conduccion/cierres/:id — el detalle de un cierre que pide atención.
  def cierre
    turno = TurnoMostrador.where(club_id: current_user.club_id).find_by(id: params[:id])
    return render json: { error: 'Cierre no encontrado' }, status: :not_found unless turno

    render json: Panel::DetalleCierre.new(turno).call
  end

  private

  def require_admin!
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin?
  end

  # El autocultivo tiene su propio inicio («Hoy»): no hay cajas, sedes ni equipo que conducir.
  def no_en_autocultivo!
    render json: { error: 'El panel es de las organizaciones' }, status: :not_found if current_user.club&.personal?
  end
end
