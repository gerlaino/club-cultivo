class SuperAdmin::ClubsController < SuperAdmin::BaseController
  before_action :set_club, only: [:show, :update, :crear_usuarios_default, :cambiar_plan, :observar, :detener_observacion, :destroy, :restaurar, :suspender, :reactivar, :provisionar_pulse, :provisionar_whatsapp, :desconectar_whatsapp, :historial]

  # Los ELIMINADOS no se listan salvo que se los pida: verlos mezclados con los activos, sin
  # distinguirse, era lo que hacía pensar que borrar una organización no hacía nada.
  def index
    clubs = Club.unscoped.includes(:users, :pacientes).order(:created_at)
    clubs = clubs.where(deleted_at: nil) unless ActiveModel::Type::Boolean.new.cast(params[:eliminados])
    render json: clubs.map { |c| serialize_club(c) }
  end

  def show
    render json: serialize_club_detail(@club)
  end

  def create
    attrs = club_params.to_h
    # Un club nuevo nace con las suites y los add-ons terminados, salvo que el alta mande otra
    # cosa: crearlo con features vacío significaría, con el gating real, una organización que no puede
    # hacer nada.
    attrs['features'] = Club::FEATURES_POR_DEFECTO.merge(attrs['features'] || {})
    # El plan no viaja en `club_params` (ver el comentario ahí), pero el alta sí lo elige.
    attrs['plan'] = PlanEnforcer.normalizar(params.dig(:club, :plan))
    club = Club.new(attrs)
    if club.save
      # Sólo los roles que el alta ofrece. No alcanza con sacarlos de la pantalla: el endpoint
      # acepta lo que le manden y un rol no ofrecido entraría igual por la API.
      roles    = (Array(params[:roles_a_crear]).map(&:to_s) & Club::ROLES_ALTA).presence || Club::ROLES_DEFAULT
      password = params[:password_inicial].presence || Club::PASSWORD_DEFAULT
      usuarios = club.crear_usuarios_default!(roles: roles, password: password)
      club.crear_geneticas_default!
      render json: {
        club:     serialize_club_detail(club),
        usuarios: usuarios.map { |u| { id: u.id, email: u.email, role: u.role } },
        # La contraseña se devuelve EN CLARO y a propósito: es temporal, la fija quien da de
        # alta y hay que poder dictársela a la organización. Ocultarla detrás de puntitos obligaba a
        # acordarse de lo que uno mismo acababa de tipear.
        password_inicial: password,
      }, status: :created
    else
      render json: { errors: club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    attrs = club_params.to_h
    # Apagar un módulo no lo corta en el momento: se programa para el fin del período pago. Se
    # resuelve acá y no en el modelo porque es una decisión del panel de plataforma — una
    # migración de datos o un rake que necesite apagar algo ya sigue escribiendo `features`.
    bajas = attrs.key?('features') ? aplicar_bajas_programadas(attrs['features']) : []

    if @club.update(attrs)
      render json: serialize_club_detail(@club.reload).merge(bajas_programadas: bajas)
    else
      render json: { errors: @club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def crear_usuarios_default
    @club.crear_geneticas_default!
    usuarios = @club.crear_usuarios_default!
    render json: { usuarios: usuarios.map { |u| { id: u.id, email: u.email, role: u.role } } }
  end

  # POST /super_admin/clubs/:id/observar — "Ingresar a la organización".
  #
  # A partir de acá el super admin navega la app como la ve la organización, en SOLO LECTURA: la organización
  # efectivo del request pasa a ser éste (ver User#club) y `block_observer_writes!` rechaza
  # cualquier escritura. Los datos clínicos quedan afuera (`block_observer_clinico!`).
  #
  # Dura una hora, no quince minutos: entrar a entender qué le pasa a una organización lleva más que
  # eso, y que se corte a la mitad de una revisión obliga a empezar de nuevo.
  DURACION_OBSERVACION = 1.hour

  def observar
    # SUSPENDIDO: ver User::OBSERVADOR_HABILITADO. No alcanza con no ponerle botón —el endpoint
    # se puede llamar igual—, y entrar a medias a una organización que está trabajando se nota.
    unless User::OBSERVADOR_HABILITADO
      return render json: {
        error: 'El modo observador está suspendido.',
        observador_suspendido: true,
      }, status: :service_unavailable
    end

    current_user.update!(
      observer_club_id:    @club.id,
      observer_token:      SecureRandom.hex(24),
      observer_expires_at: DURACION_OBSERVACION.from_now
    )
    render json: estado_observacion, status: :created
  end

  # GET /super_admin/clubs/:id/historial — qué le hicimos nosotros a esta organización.
  #
  # Es lo primero que se pregunta cuando una organización reclama: "yo no pedí que me cambien el plan",
  # "¿por qué se me apagó el Buffet?". Sólo las acciones sobre la organización (plan, módulos,
  # suspensión, baja); lo que pasa DENTRO de la organización tiene su propia auditoría por usuario.
  def historial
    registros = Auditoria.where(auditable_type: 'Club', auditable_id: @club.id)
                         .includes(:user).recientes.limit(100)

    render json: registros.map { |a|
      {
        id:      a.id,
        accion:  a.accion,
        cambios: a.cambios,
        fecha:   a.created_at,
        usuario: a.user ? { id: a.user.id, email: a.user.email, nombre: a.user.nombre_completo } : nil,
      }
    }
  end

  def detener_observacion
    current_user.update!(
      observer_club_id:    nil,
      observer_token:      nil,
      observer_expires_at: nil
    )
    head :no_content
  end

  def destroy
    @club.soft_delete!
    head :no_content
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def suspender
    @club.suspender!
    render json: serialize_club_detail(@club)
  end

  def reactivar
    @club.reactivar!
    render json: serialize_club_detail(@club)
  end

  # PATCH /super_admin/clubs/:id/provisionar_pulse
  # La API key de Pulse Grow la carga el super admin al activar el add-on de ambiente/IoT: es
  # la credencial de un servicio externo, no algo que la organización deba pegar en una pantalla.
  def provisionar_pulse
    key = params[:pulse_api_key].to_s.strip
    if key.blank?
      @club.update!(pulse_api_key: nil)
    else
      @club.pulse_api_key = key
      @club.save!
    end
    render json: serialize_club_detail(@club)
  end

  def restaurar
    @club.restaurar!
    render json: serialize_club_detail(@club)
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def cambiar_plan
    plan      = params[:plan]
    hasta     = params[:hasta]
    trial     = params[:trial]

    unless PlanEnforcer::PLANES.key?(plan)
      return render json: { error: "Plan inválido. Opciones: #{PlanEnforcer::PLANES.keys.join(', ')}" },
                    status: :unprocessable_entity
    end

    @club.update!(
      plan:             plan,
      plan_activo_hasta: hasta.present? ? Date.parse(hasta) : nil,
      plan_trial:       trial == true || trial == 'true',
      )
    render json: serialize_club_detail(@club)
  end

  # PATCH /super_admin/clubs/:id/provisionar_whatsapp — el super_admin carga las credenciales
  # de Twilio de la organización (lo que el admin no debe tocar). Al quedar completo, el estado pasa a
  # 'conectado' automáticamente.
  def provisionar_whatsapp
    sid    = params[:twilio_account_sid].to_s.strip
    token  = params[:twilio_auth_token].to_s.strip
    numero = params[:twilio_whatsapp_from].to_s.strip
    if sid.blank? || numero.blank?
      return render json: { error: 'Account SID y número son obligatorios.' }, status: :unprocessable_entity
    end
    if token.blank? && @club.twilio_auth_token_enc.blank?
      return render json: { error: 'El Auth Token es obligatorio la primera vez.' }, status: :unprocessable_entity
    end
    # Normalizar el número al formato que espera Twilio.
    numero = "whatsapp:#{numero}" unless numero.start_with?('whatsapp:')

    @club.twilio_account_sid   = sid
    @club.twilio_whatsapp_from = numero
    @club.twilio_auth_token    = token if token.present? # setter encripta; vacío = no cambiar
    @club.save!
    render json: serialize_club_detail(@club)
  end

  # DELETE /super_admin/clubs/:id/desconectar_whatsapp
  def desconectar_whatsapp
    @club.update!(twilio_account_sid: nil, twilio_auth_token_enc: nil, twilio_whatsapp_from: nil)
    render json: serialize_club_detail(@club)
  end

  private

  def estado_observacion
    {
      observando:         true,
      club_id:            @club.id,
      club_nombre:        @club.name,
      expires_at:         current_user.observer_expires_at,
      solo_lectura:       true,
      sin_acceso_clinico: true,
    }
  end

  def set_club
    @club = Club.unscoped.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Organización no encontrada' }, status: :not_found
  end

  # El plan (CUÁNTO) y los módulos (QUÉ) son dos decisiones distintas y viajan por caminos
  # distintos: el plan sólo por `cambiar_plan`, los módulos sólo acá. Aceptar `plan` en el
  # update general era lo que permitía cambiarlo sin querer al guardar otra cosa.
  def club_params
    permitidos = params.require(:club).permit(
      :name, :legal_name, :email, :phone, :website,
      :address, :city, :state, :country, :timezone,
      :plan_activo_hasta, :plan_trial, :web_activa,
      :smtp_host, :smtp_port, :smtp_user, :smtp_pass,
      :smtp_from, :smtp_from_name,
      :ia_tier, :ia_limite_hora,
      features: {}
    )
    permitidos[:features] = features_editables(permitidos[:features]) if permitidos.key?(:features)
    permitidos
  end

  # Sólo se guardan las claves que el super admin puede prender de verdad. Los módulos
  # incluidos en una suite se derivan de ella, y los que están en construcción no existen:
  # aceptarlos sería guardar un `true` que nadie lee y que después contradice a la pantalla.
  def features_editables(enviadas)
    (enviadas || {}).to_h.slice(*Club::FEATURES_EDITABLES)
  end

  # Traduce "apagá esto" a "esto termina el <fecha>", y devuelve qué quedó programado para
  # poder decírselo a quien lo apagó.
  #
  # MUTA `enviadas` a propósito: el módulo que se da de baja tiene que seguir guardado en `true`
  # hasta que venza, o la organización perdería el acceso hoy mismo — que es exactamente lo que
  # se está evitando. Prenderlo de nuevo antes del vencimiento cancela la baja.
  def aplicar_bajas_programadas(enviadas)
    programadas = []

    Club::FEATURES_EDITABLES.each do |clave|
      next unless enviadas.key?(clave)

      quiere_apagar = enviadas[clave].to_s != 'true'

      if quiere_apagar && @club.features[clave] == true
        hasta = @club.fin_de_periodo
        @club.programar_baja_modulo!(clave, hasta: hasta)
        enviadas[clave] = true # sigue andando hasta la fecha
        programadas << { modulo: clave, label: Club::ADDONS.dig(clave, :label) || clave, hasta: hasta.to_s }
      elsif !quiere_apagar && @club.baja_programada?(clave)
        @club.cancelar_baja_modulo!(clave)
      end
    end

    programadas
  end

  def serialize_club(c)
    {
      id:               c.id,
      name:             c.name,
      slug:             c.slug,
      legal_name:       c.legal_name,
      email:            c.email,
      phone:            c.phone,
      city:             c.city,
      state:            c.state,
      country:          c.country,
      plan:             c.plan,
      plan_trial:       c.plan_trial,
      plan_activo_hasta: c.plan_activo_hasta,
      usuarios_count:   c.users.count,
      pacientes_count:  c.pacientes.count,
      lotes_count:      c.lotes.count,
      created_at:       c.created_at,
      deleted_at:       c.deleted_at,
      activo:           c.activo,
      estado:           estado_de(c),
      salud:            salud_de(c),
      salud_label:      SALUD[salud_de(c)],
      # Qué contrató: la lista se ordena por suites, no por el plan viejo.
      features:         c.features_expandidas,
    }
  end

  # El estado real del módulo, calculado en el modelo: prendido no es lo mismo que andando.
  def estado_modulo(c, clave)
    { estado: c.estado_modulo(clave), falta: c.falta_para_funcionar(clave) }
  end

  # Tres estados, no dos flags que el frontend tenga que cruzar.
  def estado_de(c)
    return 'eliminado'  if c.deleted_at.present?
    return 'suspendido' unless c.activo?
    'activo'
  end

  # Cómo le está yendo, en UNA palabra. `estado_de` dice si la cuenta está viva; esto dice si
  # necesita algo — que es la pregunta con la que se abre la lista. Antes había que cruzar
  # cuatro columnas (plan, vencimiento, suites, módulos) para deducirlo organización por
  # organización.
  #
  # El orden es el mismo que la cola del panel: primero lo que cuesta plata.
  SALUD = {
    'vencida'    => 'Plan vencido',
    'sin_suites' => 'Sin suites',
    'a_medias'   => 'Módulos a medias',
    'ok'         => 'Operando',
  }.freeze

  def salud_de(c)
    return nil if c.deleted_at.present? || !c.activo? # ahí manda el estado administrativo

    return 'vencida'    if c.plan_activo_hasta.present? && c.plan_activo_hasta < Time.zone.today
    return 'sin_suites' if Club::SUITES.keys.none? { |s| c.suite?(s) }

    # Prendido ≠ andando: es la misma pregunta que responde `estado_modulo` en la ficha.
    a_medias = (Club::ADDONS.keys + Club::INCLUIDOS_EN_SUITE.keys).any? do |m|
      c.feature?(m) && c.falta_para_funcionar(m).present?
    end
    a_medias ? 'a_medias' : 'ok'
  end

  def serialize_club_detail(c)
    serialize_club(c).merge(
      website:        c.website,
      address:        c.address,
      timezone:       c.timezone,
      usuarios:       c.users.map { |u| { id: u.id, email: u.email, role: u.role, nombre: u.nombre_completo } },
      web_activa:      c.web_activa,
      smtp_configured: c.smtp_configured?,
      smtp_host:       c.smtp_host,
      smtp_port:       c.smtp_port || 587,
      smtp_user:       c.smtp_user,
      smtp_from:       c.smtp_from,
      smtp_from_name:  c.smtp_from_name,
      features:        c.features,
      # Módulos dados de baja que siguen andando hasta su fecha. El panel lo muestra para que no
      # parezca que la baja no se guardó.
      features_baja:   c.features_baja,
      pulse_configurado: c.pulse_configurado?,
      suites:          Club::SUITES.map { |k, v| { clave: k, label: v[:label], desc: v[:desc], activa: c.suite?(k) } },
      addons:          Club::ADDONS.map { |k, v|
        { clave: k, label: v[:label], desc: v[:desc], requiere: v[:requiere],
          incompleto: c.addon_incompleto?(k), activo: c.feature?(k) }.merge(estado_modulo(c, k))
      },
      # Los que vienen dentro de una suite: se muestran para que se sepa qué tiene la organización,
      # pero sin interruptor — se prenden y se apagan con la suite que los contiene.
      incluidos:       Club::INCLUIDOS_EN_SUITE.map { |k, suite|
        meta = Club::INCLUIDOS_META[k]
        { clave: k, label: meta[:label], desc: meta[:desc], requiere: meta[:requiere],
          incluido_en: suite, incluido_en_label: Club::SUITES.dig(suite, :label),
          activo: c.incluido_por_suite?(k) }.merge(estado_modulo(c, k))
      },
      # Lo que todavía no existe. Se lista para que nadie lo prometa creyendo que está.
      en_construccion: Club::EN_CONSTRUCCION.map { |k, v|
        { clave: k, label: v[:label], desc: v[:desc], requiere: v[:requiere], activo: false }
      },
      plan_info:       PlanEnforcer.new(c).info,
      ia_tier:         c.ia_tier,
      ia_limite_hora:  c.ia_limite_hora,
      # Cuánto lleva consumido este mes. Se medía desde el 11-ago y no se veía en ningún lado:
      # se podía fijar el tope sin poder mirar contra qué. Sólo se calcula si tiene el add-on —
      # son seis sumas sobre `ia_llamadas` y no tiene sentido pagarlas para una organización
      # que no usa IA.
      #
      # `with_tenant` es obligatorio: el super admin NO tiene tenant fijado (no opera ninguna
      # organización) y `IaLlamada` es tenant con `require_tenant=true`, así que sin esto la
      # ficha entera revienta con NoTenantSet. El bloque restaura el tenant anterior al salir.
      ia_uso:          c.feature?('ia') ? ActsAsTenant.with_tenant(c) { Ia::Uso.resumen_mes(c) } : nil,
      whatsapp_estado:      c.whatsapp_estado,
      whatsapp_numero:      c.whatsapp_numero,
      twilio_configurado:   c.twilio_configurado?,
      twilio_account_sid:   c.twilio_account_sid,
      twilio_whatsapp_from: c.twilio_whatsapp_from,
    )
  end
end