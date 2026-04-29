class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ActionController::MimeResponds

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Auditor global write-block: intercepta antes de cualquier acción
  before_action :block_auditor_writes!

  private

  def user_not_authorized
    render json: { error: "Forbidden" }, status: :forbidden
  end

  # Bloquea todas las operaciones de escritura HTTP para el rol auditor
  def block_auditor_writes!
    return if respond_to?(:devise_controller?, true) && devise_controller?
    return unless respond_to?(:current_user, true)
    return unless current_user&.role == "auditor"
    return if request.get? || request.head? || request.options?
    render json: { error: "Los auditores tienen acceso de solo lectura" }, status: :forbidden
  end

  # Restringe acción de escritura a admin/super_admin solamente
  def require_admin_for_write!
    unless current_user&.admin? || current_user&.super_admin?
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end
end
