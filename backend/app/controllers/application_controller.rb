class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ActionController::MimeResponds

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  before_action :inject_jwt_from_cookie
  before_action :set_current_user
  before_action :block_auditor_writes!
  before_action :block_observer_writes!

  # SPA fallback — sirve index.html para el root y las rutas del front (get '*path').
  # DEBE ser pública: una action privada no es ruteable → Rails tira ActionNotFound.
  def spa_fallback
    index_html = Rails.root.join('public', 'index.html')
    if index_html.exist?
      render file: index_html, layout: false
    else
      render json: { error: 'Not found' }, status: :not_found
    end
  end

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
    return if request.path.start_with?('/api/super_admin/', '/super_admin/')
    render json: { error: "Modo solo observación — escritura no permitida" }, status: :forbidden
  end

  def require_admin_for_write!
    unless current_user&.admin? || current_user&.super_admin?
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end

  # Expone el usuario del request a la capa de modelos (concern Auditable)
  def set_current_user
    Current.user = current_user if respond_to?(:current_user, true)
  rescue StandardError
    Current.user = nil
  end

  def inject_jwt_from_cookie
    return if request.headers['Authorization'].present?
    token = request.cookies['jwt_token']
    request.headers['Authorization'] = "Bearer #{token}" if token.present?
  end

end
