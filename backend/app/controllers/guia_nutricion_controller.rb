# La guía de nutrientes (`Nutricion::Guia`): una referencia por fase. Desde el 19-oct-2026 la LEE
# también una organización (Germán: nutrientes «como en autocultivo»); APLICARLA a los valores de
# alerta sigue siendo sólo del uso personal: una organización tiene su propio criterio agronómico y
# sus setpoints (Configuración → Alertas), y un botón no los pisa.
class GuiaNutricionController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :quien_cultiva!
  before_action :solo_autocultivo!, only: :aplicar
  before_action :require_admin!, only: :aplicar

  def show
    render json: Nutricion::Guia.new(current_user.club).to_h
  end

  def aplicar
    render json: Nutricion::Guia.new(current_user.club).aplicar!
  end

  private

  def require_admin!
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin?
  end

  def quien_cultiva!
    return if current_user.club&.personal? || %w[admin supervisor cultivador].include?(current_user.role)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def solo_autocultivo!
    return if current_user.club&.personal?
    render json: { error: 'En una organización los rangos de las alertas se configuran en Configuración → Alertas.' },
           status: :forbidden
  end
end
