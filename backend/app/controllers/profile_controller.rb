# app/controllers/profile_controller.rb
class ProfileController < ApplicationController
  before_action :authenticate_user!
  # Su propio perfil no pertenece a ninguna organización: lo edita también el super admin.
  skip_before_action :block_super_admin_sin_contexto!

  def show
    render json: { data: serialize_user(current_user) }
  end

  # Cambiar el mail pide la contraseña actual (29-oct-2026, seguridad tanda 2): el mail es a donde va
  # «Olvidé mi contraseña», así que con una sesión ajena abierta alcanzaba poner el suyo, pedir el
  # link y quedarse con la cuenta.
  def update
    if cambia_el_mail? && !clave_actual_correcta?
      return render json: { errors: [CLAVE_ACTUAL_INCORRECTA], campo: 'current_password' }, status: :unprocessable_entity
    end

    if current_user.update(profile_params)
      render json: { data: serialize_user(current_user) }, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Pide la actual (29-oct-2026, seguridad tanda 2; reemplaza la opción A del 25-sep, que no la
  # pedía): sin ella, una sesión ajena abierta —una compu del dispensario que quedó logueada—
  # alcanzaba para cambiarla y dejar afuera al dueño. Lo de antes sigue: al cambiarla se cortan las
  # sesiones de los otros dispositivos (la huella de `User#jwt_payload`) y llega un mail avisando.
  def password
    unless clave_actual_correcta?
      return render json: { errors: [CLAVE_ACTUAL_INCORRECTA], campo: 'current_password' }, status: :unprocessable_entity
    end

    if current_user.update(password_params)
      # El token de ESTA sesión se armó al autenticar, con la huella vieja: volver a fijar el
      # usuario lo rearma con la nueva (lo manda devise-jwt, ver `dispatch_requests`). Sin esto,
      # quien cambia la contraseña queda afuera en el pedido siguiente.
      bypass_sign_in(current_user, scope: :user)
      AccesoMailer.contrasena_cambiada(user: current_user).deliver_later if current_user.email_real.present?
      render json: { message: "Contraseña actualizada" }, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def avatar
    if params[:avatar].present?
      current_user.avatar.attach(params[:avatar])
      if current_user.valid?
        render json: { data: serialize_user(current_user) }, status: :ok
      else
        render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { errors: ["Archivo no recibido"] }, status: :bad_request
    end
  end

  # ── Segundo paso al entrar (29-oct-2026, seguridad tanda 2) ───────────────────────────────
  # Hoy es del super admin, que lo tiene obligatorio: hasta activarlo no opera (ver
  # `ApplicationController#exigir_segundo_paso!`). Para desactivarlo o cambiar de teléfono:
  # `rake seguridad:segundo_paso:reiniciar EMAIL=…`.
  def segundo_paso
    render json: estado_segundo_paso
  end

  # Empezar pide la contraseña: con una sesión ajena abierta, alguien podría atar la cuenta a SU
  # teléfono. Ya activo, no se rehace desde acá.
  def iniciar_segundo_paso
    return render json: { error: 'El segundo paso es del super admin.' }, status: :forbidden unless current_user.super_admin?
    return render json: { error: 'Ya está activo. Para cambiar de teléfono hay que reiniciarlo.' }, status: :conflict if current_user.segundo_paso_activo?
    unless clave_actual_correcta?
      return render json: { errors: [CLAVE_ACTUAL_INCORRECTA], campo: 'current_password' }, status: :unprocessable_entity
    end

    secreto = Seguridad::Totp.generar_secreto
    current_user.update!(otp_secret: secreto, otp_activado_at: nil, otp_ultimo_paso: nil)
    render json: { secreto: secreto, uri: Seguridad::Totp.uri(secreto, current_user.email) }
  end

  # Activar pide un código de la app: prueba que el teléfono quedó bien atado antes de exigirlo.
  def activar_segundo_paso
    return render json: { error: 'El segundo paso es del super admin.' }, status: :forbidden unless current_user.super_admin?
    return render json: { error: 'Primero escaneá el código QR.' }, status: :unprocessable_entity if current_user.otp_secret.blank?
    return render json: estado_segundo_paso if current_user.segundo_paso_activo?

    unless current_user.usar_codigo_segundo_paso!(params[:codigo])
      return render json: { error: 'El código no es correcto. Probá con el que muestra ahora la app.' }, status: :unprocessable_entity
    end

    current_user.update_columns(otp_activado_at: Time.current)
    AccesoMailer.segundo_paso_activado(user: current_user).deliver_later if current_user.email_real.present?
    render json: estado_segundo_paso
  end

  # ── Notificaciones al teléfono ─────────────────────────────────────────────
  # El backend manda la lista YA filtrada para esta persona (rol + módulos de su organización)
  # con el valor vigente de cada una; la pantalla sólo la muestra. Ver `Notificaciones::Catalogo`.
  def notificaciones
    render json: serialize_notificaciones
  end

  # Se aceptan sólo claves que a esta persona se le ofrecen: una clave ajena por la API no
  # queda guardada (ni serviría: no ofrecido = no se manda).
  def actualizar_notificaciones
    cfg    = (current_user.notificaciones_config || {}).deep_dup
    tipos  = (cfg['tipos'] ||= {})
    claves = Notificaciones::Catalogo.para(current_user).map { |t| t[:clave] }
    (params[:tipos] || {}).each do |clave, valor|
      next unless claves.include?(clave.to_s)
      tipos[clave.to_s] = ActiveModel::Type::Boolean.new.cast(valor) == true
    end
    cfg['no_molestar'] = ActiveModel::Type::Boolean.new.cast(params[:no_molestar]) == true if params.key?(:no_molestar)
    current_user.update!(notificaciones_config: cfg)
    render json: serialize_notificaciones
  end

  private

  CLAVE_ACTUAL_INCORRECTA = 'La contraseña actual no es correcta.'.freeze

  def clave_actual_correcta?
    actual = params.dig(:user, :current_password).to_s
    actual.present? && current_user.valid_password?(actual)
  end

  def cambia_el_mail?
    %i[email email_personal].any? do |campo|
      params.dig(:user)&.key?(campo) && params.dig(:user, campo).to_s.strip.downcase != current_user.public_send(campo).to_s.strip.downcase
    end
  end

  def estado_segundo_paso
    { activo: current_user.segundo_paso_activo?, obligatorio: current_user.segundo_paso_obligatorio?,
      activado_at: current_user.otp_activado_at, disponible: current_user.super_admin? }
  end

  def serialize_notificaciones
    {
      tipos: Notificaciones::Catalogo.para(current_user).map { |t|
        { clave: t[:clave], grupo: t[:grupo], **Notificaciones::Catalogo.textos(t, current_user.club),
          activo: current_user.quiere_push?(t[:clave]) }
      },
      grupos: Notificaciones::Catalogo::GRUPOS,
      no_molestar: current_user.no_molestar?,
      no_molestar_desde: User::NO_MOLESTAR_DESDE,
      no_molestar_hasta: User::NO_MOLESTAR_HASTA,
    }
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :dni, :birth_date, :email, :email_personal, :phone)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def serialize_user(u)
    {
      id: u.id,
      email: u.email,
      email_personal: u.email_personal,
      role: u.role,
      club_id: u.club_id,
      first_name: u.first_name,
      last_name: u.last_name,
      dni: u.dni,
      birth_date: u.birth_date,
      phone: u.phone,
      avatar_url: u.avatar.attached? ? url_for(u.avatar) : nil
    }
  end
end
