class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ActionController::MimeResponds

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  set_current_tenant_through_filter

  before_action :inject_jwt_from_cookie
  before_action :set_current_user
  before_action :set_tenant_from_current_user
  before_action :check_club_activo!
  before_action :block_auditor_writes!
  before_action :block_observer_writes!

  # ── Gating por módulo ─────────────────────────────────────────────────────
  #
  #   require_feature! :bar          → en un before_action del controller
  #
  # Devuelve 403 DE VERDAD. Esconder el botón en el frontend no es gating: el club puede
  # entrar por la API igual, y hasta ahora era lo único que había para 10 de los 13 flags.
  #
  # `super_admin` pasa siempre: administra la plataforma, no opera un club.
  def require_feature!(clave)
    return if current_user&.super_admin?

    club = current_user&.club
    return if club&.addon_disponible?(clave) || club&.suite?(clave)

    meta   = Club::ADDONS[clave.to_s] || Club::SUITES[clave.to_s] || {}
    nombre = meta[:label] || clave.to_s.humanize

    detalle = if Club::ADDONS_INCOMPLETOS.include?(clave.to_s)
                'Este módulo todavía no está disponible.'
              else
                'Tu club no tiene este módulo habilitado.'
              end

    render json: { error: "#{nombre}: #{detalle}", modulo: clave.to_s, requiere_modulo: true },
           status: :forbidden
  end

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

  # Un club ELIMINADO o SUSPENDIDO no opera. Vivía en BaseController, que sólo heredan una
  # decena de controllers (médico y públicos): los otros ~87 cuelgan de acá, así que eliminar
  # un club no le impedía seguir usando casi toda la API.
  def check_club_activo!
    return if current_user&.super_admin?
    return unless current_user&.club_id.present?

    club = current_user.club
    if club.nil? || club.eliminado?
      render json: { error: 'Este club fue eliminado. Contactate con soporte.' }, status: :forbidden
    elsif club.suspendido?
      # `activo` existía en la tabla y no lo miraba nadie: suspender un club no lo suspendía.
      render json: { error: 'Este club está suspendido. Contactate con soporte para reactivarlo.',
                     club_suspendido: true }, status: :forbidden
    end
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

  # Multi-tenancy (TEN-01): fija el tenant del request a partir del usuario logueado.
  # - sin usuario (público / webhooks / login) → sin tenant (require_tenant=false → sin scope)
  # - super_admin → sin tenant (opera cross-club a propósito)
  # - resto → tenant = club del usuario → queries auto-scopeadas por club_id
  def set_tenant_from_current_user
    return unless respond_to?(:current_user, true)
    user = current_user
    # Sin usuario (público / login) o super_admin (cross-club a propósito) → sin tenant.
    # Esos contextos fijan el scope ellos mismos (without_tenant / with_tenant explícito).
    return if user.nil? || user.super_admin?

    club = user.club_id && user.club
    if club
      set_current_tenant(club)
    else
      # Usuario de club sin club resoluble (cuenta huérfana). Con require_tenant=true
      # (TEN-01c) cualquier query explotaría; bloqueamos ruidoso en vez de seguir con
      # tenant nil y arriesgar una fuga entre clubes.
      Rails.logger.error("[TEN] user##{user.id} sin club resoluble (club_id=#{user.club_id.inspect})")
      render json: { error: 'Tu cuenta no tiene un club asignado. Contactá al administrador.' }, status: :forbidden
    end
  rescue StandardError => e
    Rails.logger.error("[TEN] Error fijando el tenant para user##{current_user&.id}: #{e.class} #{e.message}")
    render json: { error: 'No se pudo resolver el club de la sesión.' }, status: :internal_server_error
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
