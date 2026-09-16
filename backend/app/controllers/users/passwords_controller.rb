# «Olvidé mi contraseña», sin pasar por nadie.
#
# Hasta sep-2026 no existía: la única salida era escribirle al dueño de la plataforma, que
# reseteaba desde el panel y dictaba la clave por teléfono. Con cinco organizaciones se aguanta;
# con cuarenta es un trabajo. Devise ya traía `recoverable` en el modelo; faltaban la puerta
# (estos dos endpoints), el mail por la casilla de la PLATAFORMA —no la de la organización, que
# puede no estar conectada, y justo el admin que no puede entrar no puede conectarla— y que el
# link lleve a una pantalla de la SPA en vez de a una vista HTML que esta app (API) no tiene.
#
# Se pide por el USUARIO DE INGRESO o por el mail personal: el login puede ser `admin@slug.com`,
# que nadie recuerda, y lo que la persona sí sabe es su propio mail.
class Users::PasswordsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_tenant_from_current_user, raise: false
  skip_before_action :check_club_activo!, raise: false
  skip_before_action :check_rol_habilitado!, raise: false
  skip_before_action :block_super_admin_sin_contexto!, raise: false

  # POST /api/password — mandar el link.
  #
  # Contesta 200 siempre que no falte el dato: decir "ese usuario no existe" es regalar el
  # padrón de logins a quien pruebe direcciones. La única distinción que se hace es la que la
  # persona necesita para saber qué hacer: si su cuenta existe pero NO tiene una casilla real a
  # la que escribirle, se le dice a quién pedirle la clave — sin eso se queda esperando un mail
  # que nunca va a llegar.
  def create
    usuario = params[:usuario].to_s.strip.downcase
    if usuario.blank?
      return render json: { error: 'Escribí tu usuario o tu mail.' }, status: :unprocessable_entity
    end

    cuentas = User.where('LOWER(email) = ? OR LOWER(email_personal) = ?', usuario, usuario)
                  .where.not(role: 'paciente').to_a
    con_mail = cuentas.select { |u| u.email_real.present? }

    ActsAsTenant.without_tenant { con_mail.each { |u| Acceso::EnviarRestablecimiento.call(u) } }

    if cuentas.any? && con_mail.empty?
      render json: { enviado: false, sin_mail: true,
                     mensaje: 'Tu cuenta no tiene un mail cargado, así que no hay a dónde mandarte el link. ' \
                              'Pedile una contraseña nueva al administrador de tu organización.' }
    else
      render json: { enviado: true,
                     mensaje: 'Si la cuenta existe, te mandamos un mail con el link para elegir una contraseña nueva. ' \
                              'Vale por 6 horas. Si no te llega, revisá el correo no deseado.' }
    end
  end

  # PUT /api/password — elegir la nueva con el token del mail.
  def update
    user = User.reset_password_by_token(
      reset_password_token:  params[:token].to_s,
      password:              params[:password].to_s,
      password_confirmation: params[:password_confirmation].to_s
    )

    if user.errors.empty?
      render json: { ok: true, email: user.email }
    elsif user.errors[:reset_password_token].any?
      render json: { error: 'El link ya no sirve: venció o ya se usó. Pedí uno nuevo.', token_invalido: true },
             status: :unprocessable_entity
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
