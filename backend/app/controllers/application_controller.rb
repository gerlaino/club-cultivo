class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ActionController::MimeResponds

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  before_action :block_auditor_writes!
  before_action :block_observer_writes!

  private

  def user_not_authorized
    render json: { error: "Forbidden" }, status: :forbidden
  end

  def block_auditor_writes!
    return if respond_to?(:devise_controller?, true) && devise_controller?
    return unless respond_to?(:current_user, true)
    return unless current_user&.role == "auditor"
    return if request.get? || request.head? || request.options?
    render json: { error: "Los auditores tienen acceso de solo lectura" }, status: :forbidden
  end

  def block_observer_writes!
    return unless current_user&.super_admin?
    return unless current_user.modo_observador?
    return if request.get? || request.head? || request.options?
    return if request.path.start_with?('/super_admin/')
    render json: { error: "Modo solo observación — escritura no permitida" }, status: :forbidden
  end

  def require_admin_for_write!
    unless current_user&.admin? || current_user&.super_admin?
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end
end
