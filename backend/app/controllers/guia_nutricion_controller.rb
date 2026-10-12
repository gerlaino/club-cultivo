# La guía de nutrientes del autocultivo (`Nutricion::Guia`): verla y, si la persona quiere,
# aplicarla a sus valores de alerta. Es sólo del uso personal: una organización tiene su propio
# criterio agronómico y sus setpoints (Configuración → Alertas).
class GuiaNutricionController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :solo_autocultivo!
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

  def solo_autocultivo!
    render json: { error: 'La guía es del autocultivo' }, status: :not_found unless current_user.club&.personal?
  end
end
