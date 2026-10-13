class SuperAdmin::UsersController < SuperAdmin::BaseController
  include CambioDeRol
  def index
    # Los ÚLTIMOS arriba. Ordenado por club y rol, el usuario que acabás de crear caía en el
    # medio de la lista y había que buscarlo: en el panel de plataforma lo que se mira es lo
    # que acaba de pasar, no el padrón histórico.
    # `del_equipo` saca las cuentas de PACIENTE. Comparten tabla con el staff, así que sin el
    # scope aparecen mezcladas con el equipo de cada organización: el listado de plataforma
    # mostraba 49 pacientes de Mitocondria donde hay 6 personas trabajando, y va a empeorar con
    # cada club que cargue su padrón.
    #
    # El listado de equipo del club ya usaba el scope; éste se pasó por alto. La cuenta de un
    # paciente se gestiona SÓLO desde su ficha (`Pacientes::Acceso`), que es donde está el
    # restablecer que corresponde: por acá se le podía cambiar la contraseña sin que su ficha se
    # enterara.
    users = User.where.not(role: 'super_admin').del_equipo.includes(:club).order(created_at: :desc)
    render json: users.map { |u| serialize_user(u) }
  end

  # El alta del equipo de una organización: la única puerta desde el 12-oct-2026 (el admin la
  # pide). Las reglas viven en `Equipo::DarDeAlta`; pasarse del cupo del plan responde 409 con
  # el detalle y se confirma reenviando con `exceder_cupo: true`.
  def create
    club = Club.find(params[:user][:club_id])
    exceder = params[:exceder_cupo].presence || params.dig(:user, :exceder_cupo)
    r = Equipo::DarDeAlta.new(club: club, atributos: user_params, password: params.dig(:user, :password),
                              exceder_cupo: ActiveModel::Type::Boolean.new.cast(exceder)).call
    # En claro: es temporal y hay que poder dictársela a quien va a usarla.
    render json: serialize_user(r.user).merge(password_inicial: r.password_inicial, mail_enviado: r.mail_enviado,
                                              excede_cupo: r.excede_cupo),
           status: :created
  rescue Equipo::DarDeAlta::Error => e
    render json: { errors: [e.message], mensaje: e.message, **e.extra }, status: e.status
  end

  def update
    user = User.find(params[:id])
    # El cambio de rol es el mismo trámite que en Equipo (`Acceso::CambiarRol`).
    nuevo_rol = params.dig(:user, :role)
    attrs = user_params_update
    User.transaction do
      if user.club
        user.assign_attributes(attrs.except(:role))
        user.save!
        Acceso::CambiarRol.new(user: user, nuevo_rol: nuevo_rol, por: current_user).call!
      else
        user.update!(attrs)
      end
    end
    render json: serialize_user(user.reload)
  rescue Acceso::CambiarRol::Bloqueado => e
    render json: { errors: [e.message] }, status: e.status
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # POST /super_admin/users/:id/reset_password — "perdí la contraseña del admin".
  #
  # Es el caso que llegaba SIEMPRE al panel de plataforma: el único admin de una organización
  # pierde su clave. Desde sep-2026 el login ofrece «olvidé mi contraseña» (`Users::Passwords`),
  # así que esto queda para cuando la persona no tiene un mail real cargado o no le llega.
  #
  # No se "recupera" nada: las contraseñas se guardan hasheadas y no hay forma de leerlas. Se
  # genera una NUEVA, dictable por teléfono, y se devuelve en claro a propósito — es temporal y
  # hay que poder pasársela a la persona por el canal que sea. Devise pide cambiarla al entrar.
  #
  # Mismo comportamiento que el reset del lado del club (`ClubUsersController#reset_password`):
  # una sola forma de resetear, no dos que se parecen.
  def reset_password
    user = User.find(params[:id])
    nueva = User.password_temporal
    user.update!(password: nueva, password_confirmation: nueva)

    render json: {
      id: user.id, email: user.email, password_inicial: nueva,
      mail_enviado: enviar_instrucciones(user),
      # A dónde fue, para que quien resetea sepa qué decirle: "te llegó a tal casilla" o "no
      # tenés mail cargado, anotá esta".
      mail_destino: user.email_real,
    }
  end

  # Una baja, no un borrado: la historia de la persona queda (`Acceso::DarDeBaja`). Antes
  # devolvía 204 aunque fallara —y fallaba siempre, sin organización fijada—.
  def destroy
    user = User.find(params[:id])
    return render json: { error: 'No podés eliminar un super_admin' }, status: :forbidden if user.super_admin?

    Acceso::DarDeBaja.call(user, por: current_user)
    head :no_content
  rescue Acceso::DarDeBaja::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  # `email` es el identificador de LOGIN y `email_personal` el mail real de la persona (ver
  # `User#email_notificacion`). El alta desde el panel sólo aceptaba el primero, así que un
  # usuario creado desde acá nacía sin dirección a la que escribirle: los avisos salían al
  # login, que puede ser inventado, y rebotaban.
  # A `email_real` y por la casilla de la plataforma (`Acceso::EnviarRestablecimiento`). El mail
  # lleva el link para elegir la clave, no la temporal: la temporal es para dictar; si la
  # persona tiene mail, elige la suya.
  def enviar_instrucciones(user) = Acceso::EnviarRestablecimiento.call(user)

  def user_params
    params.require(:user).permit(:email, :email_personal, :first_name, :last_name, :role)
  end

  def user_params_update
    params.require(:user).permit(:email, :email_personal, :first_name, :last_name, :role, :password)
  end

  def serialize_user(u)
    {
      id:         u.id,
      email:      u.email,
      email_personal: u.email_personal,
      role:       u.role,
      first_name: u.first_name,
      last_name:  u.last_name,
      club_id:    u.club_id,
      club_name:  u.club&.name,
      created_at: u.created_at,
      # Cuándo entró por última vez: en la lista se lee «hoy», «hace 3 días», «nunca».
      visto_at:   u.visto_at,
    }
  end
end