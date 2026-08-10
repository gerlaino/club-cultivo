class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ActionController::MimeResponds

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  set_current_tenant_through_filter

  before_action :inject_jwt_from_cookie
  before_action :set_current_user
  before_action :set_tenant_from_current_user
  before_action :check_club_activo!
  before_action :check_rol_habilitado!
  before_action :block_auditor_writes!
  before_action :block_observer_writes!
  before_action :block_observer_clinico!
  before_action :block_super_admin_sin_contexto!

  # ── Gating por módulo ─────────────────────────────────────────────────────
  #
  #   require_feature! :bar          → en un before_action del controller
  #
  # Devuelve 403 DE VERDAD. Esconder el botón en el frontend no es gating: el club puede
  # entrar por la API igual, y hasta ahora era lo único que había para 10 de los 13 flags.
  #
  # `super_admin` pasa siempre: administra la plataforma, no opera un club.
  def require_feature!(clave)
    # El super admin pasa siempre: administra la plataforma, no opera un club. Pero cuando
    # está OBSERVANDO uno, tiene que ver exactamente lo que ve ese club — si pasara de largo
    # vería módulos que el club no compró y la observación dejaría de servir para entender qué
    # tiene delante el cliente.
    return if current_user&.super_admin? && !current_user.modo_observador?

    club = current_user&.club
    return if club&.addon_disponible?(clave) || club&.suite?(clave)

    meta   = Club::ADDONS[clave.to_s] || Club::SUITES[clave.to_s] ||
             Club::INCLUIDOS_META[clave.to_s] || Club::EN_CONSTRUCCION[clave.to_s] || {}
    nombre = meta[:label] || clave.to_s.humanize

    detalle = if Club::EN_CONSTRUCCION.key?(clave.to_s)
                'Este módulo todavía está en construcción.'
              elsif Club::ADDONS_INCOMPLETOS.include?(clave.to_s)
                'Este módulo todavía no está disponible.'
              elsif (suite = Club::INCLUIDOS_EN_SUITE[clave.to_s])
                # Viene con la suite: lo que falta no es el módulo, es lo que lo contiene.
                "Tu club no tiene la suite #{Club::SUITES.dig(suite, :label)}, que es la que lo incluye."
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

  # El club apagó la suite de la que vive este rol. El login ya lo rechaza con el mismo
  # mensaje, pero esto cubre las sesiones ABIERTAS: si el admin apaga Cultivo al mediodía, el
  # cultivador que estaba adentro tiene que enterarse, no ver 403 sueltos en cada pantalla.
  def check_rol_habilitado!
    return if current_user.nil? || current_user.super_admin?
    return if current_user.rol_habilitado?

    render json: { error: mensaje_rol_deshabilitado(current_user), modulo_rol_apagado: true },
           status: :forbidden
  end

  def mensaje_rol_deshabilitado(user)
    "Tu club no tiene activo el módulo #{user.modulo_faltante_label}, que es el que usa tu " \
      "rol (#{user.role.humanize}). Hablá con el administrador del club."
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

  # Rutas cuyo contenido es información de SALUD de pacientes: turnos con motivo de consulta,
  # fichas, indicaciones médicas.
  RUTAS_CLINICAS = ['/api/medico/', '/api/indicaciones'].freeze

  # El observador ve cómo opera el club, no la salud de sus pacientes.
  #
  # Son datos de terceros que no son del club ni nuestros (Ley 25.326 art. 8: datos sensibles),
  # y nadie los cedió para que los mire quien administra la plataforma. Hace falta un candado
  # propio porque los guards del namespace médico dejan pasar a `super_admin` a propósito —
  # para el soporte real, con la cuenta de plataforma, no para una sesión de observación.
  #
  # La historia clínica de la ficha del paciente ya queda afuera por otra vía: la allowlist de
  # PacientePolicy::ROLES_CLINICA no incluye a super_admin.
  def block_observer_clinico!
    return unless current_user&.super_admin?
    return unless current_user.modo_observador?
    return unless RUTAS_CLINICAS.any? { |p| request.path.start_with?(p) }

    render json: {
      error: 'La observación no incluye datos clínicos de pacientes.',
      observador_sin_acceso_clinico: true,
    }, status: :forbidden
  end

  def require_admin_for_write!
    unless current_user&.admin? || current_user&.super_admin?
      render json: { error: "No autorizado" }, status: :forbidden
    end
  end

  # Un super_admin NO tiene club: `current_user.club` es nil y `set_tenant_from_current_user`
  # sale sin fijar tenant. Si cae en un endpoint de organización —una pestaña vieja, un link
  # pegado, la URL escrita a mano, o una llamada a la API— el controller revienta: hay 180 usos
  # de `current_user.club.algo` fuera del panel de plataforma, y cualquiera de ellos es un
  # NoMethodError sobre nil. Con require_tenant=true (TEN-01c) los que no revientan ahí lo hacen
  # con NoTenantSet. En los dos casos el usuario ve un 500 pelado.
  #
  # Dejarlo pasar no es opción: no hay organización de la cual leer. Lo correcto es decirle que
  # le falta el contexto y cómo conseguirlo. Cuando OBSERVA una organización sí hay tenant, así
  # que ahí pasa de largo.
  #
  # Se saltea en lo que un super admin usa legítimamente: el panel de plataforma, su propio
  # perfil, /me y el login (sin este skip, cerrar sesión le devolvería 409).
  def block_super_admin_sin_contexto!
    return unless current_user&.super_admin?
    return if current_user.modo_observador?

    render json: {
      error: 'Esta pantalla es de una organización y estás en el panel de plataforma. ' \
             'Abrí la organización desde el panel para ver sus datos.',
      sin_contexto_de_club: true,
    }, status: :conflict
  end

  # Multi-tenancy (TEN-01): fija el tenant del request a partir del usuario logueado.
  # - sin usuario (público / webhooks / login) → sin tenant (require_tenant=false → sin scope)
  # - super_admin → sin tenant (opera cross-club a propósito)
  # - resto → tenant = club del usuario → queries auto-scopeadas por club_id
  def set_tenant_from_current_user
    return unless respond_to?(:current_user, true)
    user = current_user
    return if user.nil?

    # Super admin observando un club: el tenant del request ES el club observado. Sin esto el
    # observador entraba sin tenant y, con require_tenant=true (TEN-01c), no podía leer nada.
    # Es seguro: `block_observer_writes!` ya rechaza todo lo que no sea una lectura.
    if user.super_admin?
      set_current_tenant(user.observando_club) if user.modo_observador?
      # Super admin fuera del modo observador: cross-club a propósito, sin tenant. Esos
      # contextos fijan el scope ellos mismos (without_tenant / with_tenant explícito).
      return
    end

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
