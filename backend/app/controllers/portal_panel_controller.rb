# GET /api/portal_panel — la pantalla del portal del lado del admin: si está listo, qué espera que
# conteste y quiénes entran (ver `Portal::Panel`). Es del admin, como la configuración del portal.
class PortalPanelController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
    render json: Portal::Panel.de(current_user.club)
  end

  private

  def require_admin!
    render json: { error: 'Sólo el administrador de la organización.' }, status: :forbidden unless current_user.admin?
  end
end
