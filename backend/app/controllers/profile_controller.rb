# app/controllers/profile_controller.rb
class ProfileController < ApplicationController
  before_action :authenticate_user!
  # Su propio perfil no pertenece a ninguna organización: lo edita también el super admin.
  skip_before_action :block_super_admin_sin_contexto!

  def show
    render json: { data: serialize_user(current_user) }
  end

  def update
    if current_user.update(profile_params)
      render json: { data: serialize_user(current_user) }, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def password
    unless current_user.valid_password?(params.dig(:user, :current_password).to_s)
      return render json: { errors: ["La contraseña actual no es correcta"] }, status: :unprocessable_entity
    end
    if current_user.update(password_params)
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

  def serialize_notificaciones
    {
      tipos: Notificaciones::Catalogo.para(current_user).map { |t|
        { clave: t[:clave], grupo: t[:grupo], label: t[:label], desc: t[:desc], activo: current_user.quiere_push?(t[:clave]) }
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
