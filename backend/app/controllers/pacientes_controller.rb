class PacientesController < ApplicationController
  include DescargaProfesional
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  before_action :check_pacientes_role!
  before_action :set_paciente, only: [:show, :update, :destroy, :timeline, :subir_reprocann, :eliminar_reprocann, :enviar_mail, :mails_enviados, :aprobar,
                                          :invitar_portal, :iniciar_tramite_reprocann,
                                          :reprocann_aprobado, :reprocann_no_indicado, :reprocann_rechazado,
                                          :volver_a_entrevistar]
  # Hasta ahora `mailer` era una etiqueta que no controlaba nada: no había un solo
  # `require_feature!` ni chequeo en el frontend, así que el flag se podía apagar y los mails
  # seguían saliendo. Ahora que se vende aparte, la barrera va acá — el candado en el backend,
  # no sólo escondiendo el botón.
  before_action -> { require_feature!(:mailer) }, only: [:enviar_mail, :mails_enviados]
  before_action :require_export_role!, only: [:export_csv]
  before_action :require_criticos_role!, only: [:criticos]
  before_action :normalize_paciente_params, only: [:create, :update]
  before_action :warn_deprecated_route

  # ── ALLOWLIST de campos serializados ──────────────────────────────────────────
  # Campos NO clínicos: visibles para cualquier rol con lectura de la ficha.
  CAMPOS_NO_CLINICOS = %w[
    id club_id nombre apellido apodo dni dni_normalizado fecha_nacimiento es_paciente
    email telefono reprocann_numero reprocann_vencimiento reprocann_estado
    reprocann_vinculo reprocann_tramite_iniciado_el reprocann_resultado_el
    con_seguimiento_medico limite_dispensacion_mensual_g descuento_porcentaje carnet_token
    aprobado_at
    domicilio_calle domicilio_altura domicilio_piso domicilio_depto domicilio_barrio domicilio_ciudad
    created_at updated_at
  ].freeze

  # El REPROCANN no es asunto del dispensador. Su regla es más simple y no admite criterio: si el
  # paciente está en la lista, dispensa; si no está, avisa al admin. Mostrarle vencimientos lo pone
  # a decidir sobre un caso que no le toca —y a discutirlo en el mostrador con el paciente
  # enfrente—. Los casos especiales los mira admin/supervisor, que tienen la ficha completa.
  CAMPOS_REPROCANN = %w[reprocann_numero reprocann_vencimiento reprocann_estado
                        reprocann_vinculo reprocann_tramite_iniciado_el reprocann_resultado_el].freeze

  # Campos CLÍNICOS / de salud: SÓLO se agregan si el rol puede ver la historia clínica
  # (allowlist medico/admin/supervisor, via PacientePolicy#ver_notas_clinicas?).
  CAMPOS_CLINICOS = %w[
    notas_clinicas motivo_consulta anamnesis antecedentes_personales antecedentes_familiares
    diagnostico_principal diagnostico_secundario evolucion_clinica alergias
    medicacion_habitual grupo_sanguineo
  ].freeze

  def index
    page   = (params[:pagina] || 1).to_i
    limit  = (params[:limite] || 20).to_i
    query  = params[:query].to_s.strip
    dni    = params[:dni].to_s.gsub(/\D/, "")
    # El padrón se lee alfabéticamente: se entra a buscar a alguien, no a ver quién se cargó
    # último. Con `created_at desc` la lista arrancaba por el alta más reciente y encontrar a
    # una persona era recorrerla entera.
    orden  = params[:orden].presence_in(%w[created_at nombre apellido]) || "apellido"
    dir    = if params[:dir].present?
               params[:dir].to_s.downcase == "asc" ? "asc" : "desc"
             else
               orden == "created_at" ? "desc" : "asc" # lo más nuevo primero; los nombres, de la A a la Z
             end

    scope = policy_scope(Paciente)

    if params[:sin_seguimiento].present?
      scope = scope.where(con_seguimiento_medico: false)
    end

    # dni_normalizado va cifrado at-rest (determinístico) → no admite LIKE parcial,
    # sólo igualdad exacta. La búsqueda por nombre/apellido sigue siendo LIKE.
    if query.present?
      q = "%#{query.downcase}%"
      # El apodo también (6-oct-2026): «¿cómo le dicen?» es como se lo busca en el mostrador.
      by_name  = scope.where("lower(nombre) LIKE :q OR lower(apellido) LIKE :q OR lower(apodo) LIKE :q", q: q)
      dni_term = dni.presence || query.gsub(/\D/, "")
      scope = dni_term.present? ? by_name.or(scope.where(dni_normalizado: dni_term)) : by_name
    elsif dni.present?
      scope = scope.where(dni_normalizado: dni)
    end

    total    = scope.count
    # Alfabético de verdad: apellido y después nombre. Ordenar sólo por apellido deja a los
    # homónimos en orden arbitrario, que en un padrón con varios "Casuso" se nota.
    # `orden` sale de una allowlist y `dir` de un ternario: no hay interpolación de usuario.
    orden_sql = orden == "apellido" ? "apellido #{dir}, nombre #{dir}" : "#{orden} #{dir}"
    pacientes = scope.order(Arel.sql(orden_sql))
                     .offset((page - 1) * limit)
                     .limit(limit)
                     .to_a

    # Última dispensación por paciente en un solo query agrupado (evita N+1 en la lista).
    ultimas = Dispensacion.no_canceladas
                          .where(paciente_id: pacientes.map(&:id))
                          .group(:paciente_id).maximum(:fecha_dispensacion)

    # Los tres estados del paciente (19-oct-2026, `Pacientes::Situacion`) con lo que dicen sus
    # turnos al lado. No es asunto del mostrador, como el REPROCANN.
    agenda = current_user.dispensador? ? {} : Pacientes::Agenda.para(pacientes.map(&:id))

    # La LISTA nunca expone datos clínicos: allowlist estricta de campos no clínicos.
    data = pacientes.map do |p|
      fila = p.as_json(only: campos_visibles, methods: metodos_lista)
              .merge('ultima_dispensacion' => ultimas[p.id],
                     'suspendido' => Paciente.suspendido?(es_paciente: p.es_paciente, ultima_dispensacion: ultimas[p.id]))
      unless current_user.dispensador?
        fila['situacion'] = p.situacion(ultima_dispensacion: ultimas[p.id], agenda: agenda[p.id], usuario: current_user)
      end
      fila
    end

    render json: {
      data: data,
      meta: { pagina: page, limite: limit, total: total, kpis: kpis_padron(scope) }
    }
  end

  # GET /pacientes/por_carnet/:token
  # Escanear el carnet del paciente en el mostrador: devuelve a quién pertenece, dentro de la organización.
  # Un token de otro club no resuelve — el scope ya lo impide.
  def por_carnet
    paciente = policy_scope(Paciente).find_by(carnet_token: params[:token])
    return render json: { error: 'Carnet no encontrado' }, status: :not_found unless paciente

    render json: { data: paciente.as_json(only: campos_visibles, methods: [:nombre_completo]) }
  end

  def show
    authorize @paciente

    # Base: SÓLO campos no clínicos (allowlist), para cualquier rol con lectura.
    metodos = [:nombre_completo, :dispensado_mes_actual_g, :porcentaje_limite_mensual, :saldo_cc,
               :limite_cc, :saldo_cc_g, :limite_cc_g, :cc_gramos_activo]
    metodos += %i[reprocann_estado_efectivo reprocann_categoria] unless current_user.dispensador?
    json = @paciente.as_json(only: campos_visibles, methods: metodos)

    # Los médicos que lo atienden y si tiene una entrevista pendiente (6-oct-2026). Fuera del mostrador.
    unless current_user.dispensador?
      json['medicos'] = @paciente.medico_pacientes.includes(:medico).map { |v| { medico_id: v.medico_id, nombre: v.medico&.nombre_completo } }
      json['situacion'] = situacion_de(@paciente)
      # El motivo de «No indicado» / «Rechazado» es de salud: lo ve quien ve el REPROCANN.
      json['reprocann_resultado_motivo'] = @paciente.reprocann_resultado_motivo if @paciente.reprocann_cerrado?
      # La constancia de renovación que subió el paciente desde el portal y espera revisión.
      json['renovacion_portal'] = renovacion_portal_json(@paciente)
    end

    # Historia clínica: se agrega SÓLO si el rol puede verla (medico/admin/supervisor).
    if policy(@paciente).ver_notas_clinicas?
      json.merge!(@paciente.as_json(only: CAMPOS_CLINICOS))
    end

    json['reprocann_documento_url'] = url_for(@paciente.reprocann_documento) if @paciente.reprocann_documento.attached?

    ultima = @paciente.dispensaciones.includes(:stock).recientes.first
    json['suspendido'] = Paciente.suspendido?(es_paciente: @paciente.es_paciente,
                                              ultima_dispensacion: @paciente.dispensaciones.no_canceladas.maximum(:fecha_dispensacion))
    json['ultima_dispensacion'] = ultima ? {
      fecha:          ultima.fecha_dispensacion,
      cantidad:       ultima.cantidad,
      forma_producto: ultima.stock&.forma_producto,
    } : nil

    json['acceso'] = acceso_json(@paciente)

    render json: { data: json }
  end

  # POST /pacientes/:id/iniciar_tramite_reprocann — «Inicié el trámite» (Javi, 6-oct-2026). El
  # médico (de sus pacientes) o administración. El estado pasa a «en trámite» con la fecha, y como es
  # el mismo campo para toda la app, se ve en todos lados; administración recibe un aviso.
  def iniciar_tramite_reprocann
    paso_del_reprocann { @paciente.iniciar_tramite_reprocann!(por: current_user) }
  end

  # POST /pacientes/:id/reprocann_aprobado — llegó aprobado: número y vencimiento, y queda activo.
  def reprocann_aprobado
    paso_del_reprocann do
      @paciente.cargar_reprocann_aprobado!(por: current_user, numero: params[:numero].to_s.strip,
                                           vencimiento: params[:vencimiento])
    end
  end

  # POST /pacientes/:id/reprocann_no_indicado — la médica decide no pedirlo (con motivo). Queda inactivo.
  def reprocann_no_indicado
    paso_del_reprocann { @paciente.marcar_no_indicado!(por: current_user, motivo: params[:motivo]) }
  end

  # POST /pacientes/:id/reprocann_rechazado — el Ministerio rechazó el trámite (con motivo). Queda inactivo.
  def reprocann_rechazado
    paso_del_reprocann { @paciente.marcar_rechazado!(por: current_user, motivo: params[:motivo]) }
  end

  # POST /pacientes/:id/volver_a_entrevistar — vuelve al ciclo y a estar activo. Reactivar es de
  # administración, como toda alta (el médico se ocupa sólo de la salud).
  def volver_a_entrevistar
    return render json: { error: 'Sólo administración reactiva a un paciente.' }, status: :forbidden unless admin_de_la_org?

    paso_del_reprocann { @paciente.volver_a_entrevistar!(por: current_user) }
  end

  # POST /pacientes/:id/acceso/invitar — el link para que el paciente entre a su portal (27-oct-2026).
  #
  # Reemplaza a «Crear su acceso» y «Generar contraseña nueva», que mostraban una contraseña UNA
  # vez para dictársela: ahora el paciente la elige él, desde el link, poniendo su DNI. Sirve igual
  # para el que nunca entró y para el que perdió la clave; cada link nuevo anula el anterior.
  def invitar_portal
    return unless autorizado_para_acceso?

    resultado = PortalAcceso::Invitar.call(@paciente, creado_por: current_user)
    return render json: { errors: [resultado.error] }, status: :unprocessable_entity unless resultado.ok?

    render json: { data: acceso_json(@paciente.reload), link: link_json(resultado) }, status: :created
  end

  def subir_reprocann
    authorize @paciente, :update?
    unless params[:archivo].present?
      return render json: { error: 'No se recibió ningún archivo' }, status: :unprocessable_entity
    end
    @paciente.reprocann_documento.attach(params[:archivo])
    render json: { reprocann_documento_url: url_for(@paciente.reprocann_documento) }
  end

  def eliminar_reprocann
    authorize @paciente, :update?
    @paciente.reprocann_documento.purge if @paciente.reprocann_documento.attached?
    head :no_content
  end

  def timeline
    authorize @paciente, :timeline?
    eventos = []

    @paciente.dispensaciones.order(created_at: :desc).limit(50).each do |d|
      eventos << {
        tipo: 'dispensacion',
        fecha: d.created_at,
        descripcion: "Dispensación: #{d.cantidad}#{d.unidad_display rescue ''} — $#{d.aporte_socio_ars}",
        id: d.id
      }
    end

    @paciente.notas.order(created_at: :desc).each do |n|
      eventos << {
        tipo: 'nota',
        fecha: n.created_at,
        descripcion: n.contenido.to_s.truncate(120),
        id: n.id
      }
    end

    @paciente.indicacion_medicas.order(created_at: :desc).each do |i|
      eventos << {
        tipo: 'indicacion',
        fecha: i.created_at,
        descripcion: "Indicación médica registrada",
        id: i.id
      }
    end

    @paciente.turnos.includes(:medico).order(fecha_hora: :desc).each do |t|
      tipo_label = { 'primera_vez' => 'Primera vez', 'seguimiento' => 'Seguimiento', 'revision' => 'Revisión', 'urgencia' => 'Urgencia' }
      estado_label = { 'programado' => 'Programado', 'confirmado' => 'Confirmado', 'realizado' => 'Realizado', 'cancelado' => 'Cancelado', 'ausente' => 'Ausente' }
      desc = "Turno #{tipo_label[t.tipo] || t.tipo}"
      desc += " con #{t.medico&.nombre_completo}" if t.medico
      desc += " — #{estado_label[t.estado] || t.estado}"
      desc += " — #{t.motivo.truncate(60)}" if t.motivo.present?
      eventos << {
        tipo:        'turno',
        fecha:       t.fecha_hora,
        descripcion: desc,
        estado:      t.estado,
        id:          t.id
      }
    end

    eventos << {
      tipo: 'alta',
      fecha: @paciente.created_at,
      descripcion: "Alta como paciente de la organización",
      id: nil
    }

    render json: { timeline: eventos.sort_by { |e| e[:fecha] }.reverse }
  end

  def create
    unless Paciente::ROLES_CREAN.include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_paciente?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('pacientes', info[:limites][:pacientes], plan: info[:label]), status: :payment_required
    end

    paciente = Paciente.new(paciente_params)
    paciente.club_id    = current_user.club_id
    paciente.created_by = current_user
    paciente.updated_by = current_user

    paciente.con_seguimiento_medico = false if current_user.dispensador?

    # Quien puede aprobar, aprueba en el mismo acto: para admin y médico dar de alta ES admitir,
    # y pedirles un segundo click sobre su propia alta sería burocracia sin sentido. El
    # mostrador (dispensador, supervisor) carga la solicitud y queda pendiente — el modelo pone
    # la fecha de aprobación salvo que se lo marque así.
    if Paciente::ROLES_APRUEBAN.include?(current_user.role)
      paciente.aprobado_por = current_user
    else
      paciente.desde_mostrador = true
    end

    if Paciente::REPROCANN_CERRADOS.include?(paciente.reprocann_estado)
      return render json: { errors: ['Un alta no nace «No indicado» ni «Rechazado».'] }, status: :unprocessable_entity
    end

    turno = turno_del_alta(paciente)
    return if performed?

    guardado = Paciente.transaction do
      next false unless paciente.save
      next true unless turno

      turno.paciente = paciente
      next true if turno.save

      # El turno no entró (horario ocupado, ya pasó…): no queda un alta a medias.
      paciente.errors.add(:base, "El turno: #{turno.errors.full_messages.to_sentence}")
      raise ActiveRecord::Rollback
    end

    if guardado
      Turnos::AvisarMedico.call(turno, cambio: :nuevo, por: current_user) if turno
      # La «dirección de entrega distinta» del alta es la primera dirección guardada (con su
      # nombre y por defecto). Las columnas `envio_*` de `pacientes` ya no se escriben.
      guardar_direccion_de_entrega!(paciente)
      avisar_alta_pendiente(paciente) if paciente.pendiente_aprobacion?
      # Sólo sale acá si el alta ya quedó aprobada (admin o médico). La cargada desde el
      # mostrador todavía no es paciente de la organización: darle la bienvenida antes de que
      # alguien la admita sería anunciarle algo que puede no pasar. Esa sale al aprobar.
      aviso = enviar_bienvenida(paciente) unless paciente.pendiente_aprobacion?
      acceso = crear_acceso(paciente) unless paciente.pendiente_aprobacion?
      render json: { data: paciente_json(paciente), aviso: aviso, acceso: acceso }.compact, status: :created
    else
      render json: { errors: paciente.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /pacientes/:id/aprobar — admitir a alguien cargado desde el mostrador.
  def aprobar
    unless Paciente::ROLES_APRUEBAN.include?(current_user.role)
      return render json: { error: 'Sólo administración puede aprobar un alta.' },
                    status: :forbidden
    end

    if @paciente.aprobado?
      return render json: { error: 'Este paciente ya estaba aprobado.' }, status: :unprocessable_entity
    end

    @paciente.aprobar!(current_user)
    aviso  = enviar_bienvenida(@paciente)
    acceso = crear_acceso(@paciente)
    render json: { data: paciente_json(@paciente), aviso: aviso, acceso: acceso }.compact
  end

  def update
    unless %w[admin super_admin medico].include?(current_user.role)
      return render json: { error: 'Sólo administración modifica los datos del paciente.' }, status: :forbidden
    end
    if current_user.medico?
      fuera = ((params[:paciente] || params[:socio])&.keys.to_a - Paciente::CAMPOS_SALUD)
      if fuera.any?
        return render json: { error: 'El médico sólo modifica datos de salud: REPROCANN e historia clínica.' },
                      status: :forbidden
      end
    end

    if params_include_notas_clinicas? && !can_edit_notas_clinicas?
      return render json: { error: 'No autorizado para modificar notas clínicas' }, status: :forbidden
    end

    raw = params[:paciente] || params[:socio]
    if raw&.key?(:con_seguimiento_medico) && current_user.dispensador?
      return render json: { error: 'No autorizado para modificar seguimiento médico' }, status: :forbidden
    end

    attrs = paciente_params
    if Paciente::REPROCANN_CERRADOS.include?(attrs[:reprocann_estado].to_s) && attrs[:reprocann_estado] != @paciente.reprocann_estado
      return render json: { errors: ['«No indicado» y «Rechazado» se marcan desde la ficha, con el motivo.'] },
                    status: :unprocessable_entity
    end

    @paciente.assign_attributes(attrs)
    @paciente.updated_by = current_user

    if @paciente.save
      render json: { data: @paciente }
    else
      render json: { errors: @paciente.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Sólo administración (15-oct-2026): antes no había chequeo y el médico tenía el tachito.
  def destroy
    unless current_user.admin? || current_user.super_admin?
      return render json: { error: 'Sólo administración elimina pacientes.' }, status: :forbidden
    end

    @paciente.update!(deleted_by_id: current_user.id)
    @paciente.destroy
    head :no_content
  end

  # GET /pacientes/criticos
  def criticos
    hoy   = Time.zone.today
    club  = current_user.club

    por_fecha = club.pacientes
      .where.not(reprocann_vencimiento: nil)
      .where('reprocann_vencimiento < ?', hoy)
      .where(reprocann_estado: %w[activo pendiente])
    # Más los marcados «Vencido» a mano (6-oct), que pueden no tener fecha: sin días que contar.
    reprocann_vencidos = por_fecha.or(club.pacientes.where(reprocann_estado: 'vencido'))
      .select(:id, :nombre, :apellido, :reprocann_vencimiento, :reprocann_estado)
      .map { |p| { id: p.id, nombre: p.nombre_completo, reprocann_vencimiento: p.reprocann_vencimiento,
                   dias_vencido: p.reprocann_vencimiento && p.reprocann_vencimiento < hoy ? (hoy - p.reprocann_vencimiento).to_i : nil } }

    reprocann_por_vencer = club.pacientes
      .where('reprocann_vencimiento > ? AND reprocann_vencimiento <= ?', hoy, 30.days.from_now)
      .where(reprocann_estado: %w[activo pendiente])
      .select(:id, :nombre, :apellido, :reprocann_vencimiento, :reprocann_estado)
      .map { |p| { id: p.id, nombre: p.nombre_completo, reprocann_vencimiento: p.reprocann_vencimiento, dias_restantes: (p.reprocann_vencimiento - hoy).to_i } }

    sin_dispensacion_ids = Dispensacion
      .joins(:paciente)
      .where(pacientes: { club_id: club.id })
      .where('dispensaciones.fecha_dispensacion >= ?', 60.days.ago)
      .pluck(:paciente_id).uniq

    sin_dispensacion_reciente = club.pacientes
      .where(reprocann_estado: 'activo')
      .where.not(id: sin_dispensacion_ids)
      .select(:id, :nombre, :apellido, :created_at)
      .order(created_at: :asc)
      .limit(20)
      .map { |p| { id: p.id, nombre: p.nombre_completo } }

    render json: {
      reprocann_vencidos:,
      reprocann_por_vencer:,
      sin_dispensacion_reciente:,
      total: reprocann_vencidos.size + reprocann_por_vencer.size + sin_dispensacion_reciente.size,
    }
  end

  # GET /pacientes/export_csv
  def export_csv
    scope = policy_scope(Paciente)

    case params[:reprocann]
    when 'proximos'
      scope = scope.where('reprocann_vencimiento > ? AND reprocann_vencimiento <= ?', Time.zone.today, 30.days.from_now)
    when 'vencidos'
      scope = scope.where('reprocann_vencimiento < ?', Time.zone.today)
    when 'sin_rep'
      scope = scope.where(reprocann_vencimiento: nil)
    end

    if params[:query].present?
      q = "%#{params[:query].downcase}%"
      # Igual que la pantalla (con apodo): la descarga trae lo mismo que se ve.
      by_name  = scope.where("lower(nombre) LIKE :q OR lower(apellido) LIKE :q OR lower(apodo) LIKE :q", q: q)
      dni_term = params[:query].gsub(/\D/, "")
      scope = dni_term.present? ? by_name.or(scope.where(dni_normalizado: dni_term)) : by_name
    end

    scope = scope.order(apellido: :asc, nombre: :asc)

    # Lo mismo que la lista, en Excel o PDF (`DescargaProfesional`). Sin el id interno ni el
    # «límite mensual» (no existe), y el REPROCANN con la misma categoría que la pantalla.
    estado_rep = { 'vigente' => 'Vigente', 'por_vencer' => 'Vence en 30 días', 'vencido' => 'Vencido',
                   'pendiente' => 'En trámite', 'sin_reprocann' => 'Sin REPROCANN' }
    pacientes = scope.to_a
    filtro = { 'proximos' => 'REPROCANN que vence en 30 días', 'vencidos' => 'REPROCANN vencido',
               'sin_rep' => 'Sin REPROCANN' }[params[:reprocann]]
    filtro = [filtro, ("búsqueda «#{params[:query]}»" if params[:query].present?)].compact.join(' · ').presence
    responder_descarga(
      titulo: 'Pacientes', nombre: 'pacientes', filtros: filtro,
      kpis: [{ label: 'Pacientes', valor: pacientes.size },
             { label: 'REPROCANN vigente', valor: pacientes.count { |p| %w[vigente por_vencer].include?(p.reprocann_categoria) } }],
      headers: ['Apellido', 'Nombre', 'DNI', 'Nacimiento', 'Email', 'Teléfono', 'N° REPROCANN',
                'Vence', 'REPROCANN', 'Seguimiento médico', 'Alta'],
      columnas_pdf: [0, 1, 2, 3, 5, 6, 7, 8],
      formatos: %i[texto texto texto fecha texto texto texto fecha texto texto fecha],
      rows: pacientes.map { |p|
        [p.apellido, p.nombre, p.dni_normalizado, p.fecha_nacimiento, p.email, p.telefono, p.reprocann_numero,
         p.reprocann_vencimiento, estado_rep[p.reprocann_categoria], p.con_seguimiento_medico ? 'Sí' : 'No',
         p.created_at.to_date]
      },
    )
  end

  # POST /pacientes/:id/enviar_mail
  def enviar_mail
    unless %w[admin supervisor].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    # El asunto y el cuerpo llegan YA resueltos desde la vista previa: lo que el usuario vio en
    # pantalla es exactamente lo que se manda. `plantilla_mail_id` queda sólo como rastro de con
    # cuál se armó, para el historial.
    plantilla = if (pid = params.dig(:mail, :plantilla_mail_id)).present?
                  current_user.club.plantillas_mail.find_by(id: pid)
                end

    resultado = Correo::EnviarAPaciente.call(
      paciente:  @paciente,
      usuario:   current_user,
      asunto:    params.dig(:mail, :asunto),
      cuerpo:    params.dig(:mail, :cuerpo),
      tipo:      params.dig(:mail, :tipo).presence_in(MailEnviado::TIPOS) || 'personalizado',
      plantilla: plantilla
    )

    return render json: { error: resultado.error }, status: :unprocessable_entity unless resultado.ok?

    render json: serialize_mail(resultado.mail), status: :created
  end

  # GET /pacientes/:id/mails_enviados
  def mails_enviados
    unless %w[admin supervisor].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    mails = @paciente.mails_enviados.recientes.limit(50).includes(:user, :plantilla_mail)
    render json: mails.map { |m| serialize_mail(m) }
  end

  private

  def admin_de_la_org? = current_user.admin? || current_user.super_admin?

  # Un paso del ciclo del REPROCANN: sólo salud (admin y médico; el médico, de sus vinculados —ya lo
  # filtra `set_paciente`). El modelo valida que se pueda dar desde el estado actual.
  def paso_del_reprocann
    unless admin_de_la_org? || current_user.medico?
      return render json: { error: 'Sólo el médico o administración.' }, status: :forbidden
    end

    yield
    render json: { data: { id: @paciente.id, situacion: situacion_de(@paciente.reload) } }
  rescue Paciente::PasoInvalido => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def situacion_de(paciente)
    paciente.situacion(ultima_dispensacion: paciente.dispensaciones.no_canceladas.maximum(:fecha_dispensacion),
                       agenda: Pacientes::Agenda.para([paciente.id])[paciente.id], usuario: current_user)
  end

  # El turno opcional del alta (19-oct-2026): con quién y cuándo. Lo da administración —la agenda de
  # los médicos es suya—; el turno vincula solo al paciente con el médico (`Turno`).
  def turno_del_alta(paciente)
    t = params[:turno]
    return nil if t.blank? || t[:medico_id].blank?

    unless admin_de_la_org?
      render json: { errors: ['Sólo administración da turnos al dar el alta.'] }, status: :forbidden
      return nil
    end
    medico = current_user.club.users.find_by(id: t[:medico_id], role: 'medico')
    unless medico
      render json: { errors: ['El médico elegido no es de esta organización.'] }, status: :unprocessable_entity
      return nil
    end

    turno = current_user.club.turnos.new(
      medico: medico, fecha_hora: t[:fecha_hora], duracion_minutos: (t[:duracion_minutos].presence || 30).to_i,
      tipo: t[:tipo].presence_in(Turno::TIPOS) || 'primera_vez', motivo: t[:motivo].presence, estado: 'programado'
    )
    turno.agendando = true
    turno
  end

  # Los contadores de la cabecera se cuentan sobre TODO el padrón, no sobre la página.
  # Contarlos en el cliente sobre `store.items` hacía que una organización de 38 pacientes mostrara
  # "20 en la nómina" y "0 REPROCANN vencido" teniendo vencidos en la página 2 — el admin lee
  # ese cero y se queda tranquilo. Mismo criterio que Medico::PacientesController#kpis.
  #
  # Espeja la PRECEDENCIA de `reprocannCategoria` (frontend/src/composables/useReprocann.js):
  # primero el trámite pendiente, después la falta de certificado, y recién ahí la fecha. Si
  # las dos se separan, la tarjeta y la lista que esa tarjeta filtra dejan de coincidir.
  # Los contadores, con la MISMA cuenta que cada fila (`Pacientes::Situacion`): una tarjeta y la
  # lista que filtra no pueden decir números distintos. Se cuentan sobre la nómina (los activos en la
  # organización), salvo «dados de baja» y «no indicados / rechazados», que son justamente los que
  # quedaron afuera.
  def kpis_padron(scope)
    hoy = Time.zone.today
    filas = scope.select(:id, :es_paciente, :aprobado_at, :reprocann_estado, :reprocann_numero,
                         :reprocann_vencimiento, :reprocann_vinculo).to_a
    ultimas = Dispensacion.no_canceladas.where(paciente_id: scope.select(:id))
                          .group(:paciente_id).maximum(:fecha_dispensacion)
    agenda = current_user.dispensador? ? {} : Pacientes::Agenda.para(filas.select(&:es_paciente).map(&:id))

    k = Hash.new(0)
    filas.each do |p|
      rep = Pacientes::Situacion.reprocann(estado: p.reprocann_estado, numero: p.reprocann_numero,
                                           vencimiento: p.reprocann_vencimiento, vinculo: p.reprocann_vinculo, hoy: hoy)
      k[:cerrados] += 1 if Pacientes::Situacion::CERRADOS.include?(rep)
      next k[:baja] += 1 unless p.es_paciente

      k[:total] += 1
      k[:pendientes_aprobacion] += 1 if p.aprobado_at.nil?
      k[:inactivos] += 1 if Paciente.suspendido?(es_paciente: true, ultima_dispensacion: ultimas[p.id], hoy: hoy)
      if p.reprocann_vinculo == 'otra_organizacion'
        k[:adherentes] += 1
      else
        k[:vinculados] += 1
      end
      k[:entrevista_pendiente] += 1 if Pacientes::Situacion.pendiente_entrevista?(rep, vencimiento: p.reprocann_vencimiento,
                                                                                 vinculo: p.reprocann_vinculo, hoy: hoy)
      k[:pendientes] += 1 if rep == 'pendiente_aprobacion'
      k[:vencidos]   += 1 if rep == 'vencido'
      k[:proximos]   += 1 if rep == 'activo' && Pacientes::Situacion.vence_en_dias(p.reprocann_vencimiento, hoy: hoy)
      k[:falto_turno] += 1 if agenda.dig(p.id, :falto_turno_el)
    end

    %i[total baja pendientes_aprobacion pendientes adherentes vinculados entrevista_pendiente falto_turno
       vencidos proximos inactivos cerrados].index_with { |key| k[key] }
  end

  def campos_visibles
    return CAMPOS_NO_CLINICOS - CAMPOS_REPROCANN if current_user.dispensador?
    CAMPOS_NO_CLINICOS
  end

  def metodos_lista
    return [:nombre_completo] if current_user.dispensador?
    [:nombre_completo, :reprocann_estado_efectivo, :reprocann_categoria]
  end


  def serialize_mail(m)
    {
      id:            m.id,
      asunto:        m.asunto,
      cuerpo:        m.cuerpo,
      tipo:          m.tipo,
      email_destino: m.email_destino,
      enviado_at:    m.enviado_at,
      remitente:     m.user.nombre_completo,
      # Con qué plantilla salió, para el badge del historial. Nil si fue escrito libre o si es
      # de antes de que las plantillas existieran; ahí el frontend cae en `tipo`.
      plantilla_nombre: m.plantilla_mail&.nombre
    }
  end

  def set_paciente
    @paciente = policy_scope(Paciente).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def normalize_paciente_params
    p = params[:paciente] || params[:socio]
    return unless p.is_a?(ActionController::Parameters)
    params[:paciente] = p
    p[:nombre]           ||= p.delete(:first_name)  if p[:first_name]
    p[:apellido]         ||= p.delete(:last_name)   if p[:last_name]
    p[:fecha_nacimiento] ||= p.delete(:birthday)    if p[:birthday]
    p[:telefono]         ||= p.delete(:phone)       if p[:phone]

    if p[:fecha_nacimiento].present? && p[:fecha_nacimiento] =~ %r{\A\d{2}/\d{2}/\d{4}\z}
      d, m, y = p[:fecha_nacimiento].split("/")
      p[:fecha_nacimiento] = "#{y}-#{m}-#{d}"
    end
  end

  def paciente_params
    allowed = %i[nombre apellido apodo dni fecha_nacimiento es_paciente email telefono reprocann_numero reprocann_vencimiento reprocann_estado
                 reprocann_vinculo
                 domicilio_calle domicilio_altura domicilio_piso domicilio_depto domicilio_barrio domicilio_ciudad]
    if current_user&.admin? || current_user&.super_admin?
      allowed += %i[limite_dispensacion_mensual_g descuento_porcentaje]
    end
    allowed << :notas_clinicas          if can_edit_notas_clinicas?
    allowed << :con_seguimiento_medico  if current_user&.admin? || current_user&.medico?
    if can_edit_notas_clinicas?
      allowed += %i[motivo_consulta anamnesis antecedentes_personales antecedentes_familiares
                    diagnostico_principal diagnostico_secundario evolucion_clinica
                    alergias medicacion_habitual grupo_sanguineo]
    end
    (params[:paciente] || params[:socio]).permit(*allowed)
  end

  def params_include_notas_clinicas?
    p = params[:paciente] || params[:socio]
    p.present? && p.key?(:notas_clinicas)
  end

  def can_edit_notas_clinicas?
    %w[admin medico].include?(current_user&.role)
  end

  # Los campos `envio_*` del alta —«dirección de entrega distinta»— van a `DireccionPaciente`,
  # no a las columnas viejas. Sólo si vino calle.
  def guardar_direccion_de_entrega!(paciente)
    p = params[:paciente] || {}
    return if p[:envio_calle].blank?

    paciente.direcciones_guardadas.create!(
      club: paciente.club, etiqueta: p[:envio_etiqueta].presence || 'Envío',
      calle: p[:envio_calle], altura: p[:envio_altura], piso: p[:envio_piso], depto: p[:envio_depto],
      barrio: p[:envio_barrio], ciudad: p[:envio_ciudad],
    )
  end

  def check_pacientes_role!
    blocked = %w[delivery abogado cultivador manicura auditor]
    if blocked.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def require_export_role!
    unless %w[admin medico super_admin].include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def require_criticos_role!
    unless %w[admin supervisor super_admin].include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def warn_deprecated_route
    if request.path.start_with?('/socios')
      Rails.logger.warn "[DEPRECATED] /socios hit by #{current_user&.email} — migrate to /pacientes"
    end
  end

  # Serialización de una ficha para create/aprobar: la misma allowlist que el resto, sin datos
  # clínicos. Antes `create` devolvía el modelo entero — todos los campos, incluidos los cifrados
  # que se descifran al serializar.
  def paciente_json(paciente)
    paciente.as_json(only: campos_visibles, methods: [:nombre_completo])
  end

  # Su cuenta del portal, para poder verla en la ficha. Sin esto la contraseña inicial se mostraba
  # una vez al dar el alta y después no había NINGÚN lugar donde ver siquiera cuál era el usuario.
  #
  # `activo` es el mismo interruptor que ya le impide dispensar: si el paciente está desactivado,
  # la cuenta existe pero no entra, y la ficha tiene que decirlo o parece que el portal se rompió.
  def acceso_json(paciente)
    club = current_user.club
    return { modulo: false } unless club.feature?(:vista_paciente)

    user    = paciente.user
    vigente = paciente.accesos_portal.where(usado_at: nil, anulado_at: nil).where('expira_at > ?', Time.current)
                      .order(created_at: :desc).first
    {
      modulo:          true,
      portal_abierto:  club.portal_paciente_disponible?,
      activo:          paciente.es_paciente?,
      # Entra con su DNI. «Activó» = eligió su clave desde un link (antes de esto no hay forma de
      # que la sepa: la inicial no se le muestra a nadie).
      activado:        paciente.accesos_portal.where.not(usado_at: nil).exists?,
      ultimo_ingreso:  user&.visto_at,
      link_vigente:    vigente && { motivo: vigente.motivo, expira_at: vigente.expira_at, creado_at: vigente.created_at },
      tiene_mail:      paciente.email.present?,
      puede_gestionar: Paciente::ROLES_APRUEBAN.include?(current_user.role),
    }
  end

  def renovacion_portal_json(paciente)
    r = paciente.reprocann_renovaciones.del_portal.where(estado: 'en_tramite').recientes.first
    return nil unless r

    { id: r.id, subida_at: r.created_at,
      constancia_url: r.constancia.attached? ? url_for(r.constancia) : nil,
      constancia_nombre: r.constancia.attached? ? r.constancia.filename.to_s : nil,
      es_imagen: r.constancia.attached? && r.constancia.content_type.to_s.start_with?('image/') }
  end

  def link_json(resultado)
    { url: resultado.link, expira_at: resultado.expira_at, texto: resultado.texto, mail_enviado: resultado.mail_enviado }
  end

  # La cuenta la maneja quien admite pacientes. El mostrador crea altas pero no reparte accesos:
  # es la misma línea que ya separa cargar una solicitud de aprobarla.
  def autorizado_para_acceso?
    unless current_user.club.feature?(:vista_paciente)
      render json: { errors: ['Tu organización no tiene el Portal del paciente.'] }, status: :forbidden
      return false
    end
    unless Paciente::ROLES_APRUEBAN.include?(current_user.role)
      render json: { errors: ['Sólo administración gestiona el acceso al portal.'] },
             status: :forbidden
      return false
    end
    true
  end

  # El alta quedó pendiente: alguien tiene que aprobarla para que esa persona pueda retirar.
  #
  # Reemplaza al aviso viejo ("creó un paciente sin seguimiento médico"), que era informativo y
  # se diluía entre otras alertas. Ahora describe algo que hay que HACER, va en severidad
  # `warning` y llega también al médico, que es quien además puede aprobarla.
  def avisar_alta_pendiente(paciente)
    Paciente::ROLES_APRUEBAN.each do |rol|
      AlertaInterna.create!(
        club_id:          current_user.club_id,
        tipo:             'paciente_pendiente_aprobacion',
        mensaje:          "#{current_user.nombre_completo} cargó a #{paciente.nombre_completo} desde el mostrador. " \
                          'Está pendiente de aprobación y no puede recibir dispensaciones hasta que lo apruebes.',
        severidad:        'warning',
        creada_por:       current_user,
        destinada_a_role: rol,
        contexto:         { paciente_id: paciente.id, creado_por_id: current_user.id }
      )
    end
  end

  # La cuenta del portal nace cuando el paciente queda ADMITIDO, igual que el mail de bienvenida:
  # una solicitud cargada en el mostrador que todavía nadie aprobó no es paciente de la
  # organización, y darle acceso antes sería dejarlo entrar a algo que puede no pasar.
  #
  # Devuelve las credenciales para que quien dio el alta se las pase en mano. Nunca hace fallar la
  # operación: el paciente quedó dado de alta igual, y sin cuenta se le crea después.
  def crear_acceso(paciente)
    club = current_user.club
    return unless club.feature?(:vista_paciente)
    # Con el portal cerrado la cuenta se crea igual (para invitarlo cuando lo abran), pero no se
    # manda un link que hoy no abriría nada.
    unless club.portal_paciente_disponible?
      resultado = Pacientes::Acceso.crear!(paciente)
      return resultado.ok? ? nil : { error: resultado.error }
    end

    resultado = PortalAcceso::Invitar.call(paciente, creado_por: current_user)
    resultado.ok? ? { link: link_json(resultado) } : { error: resultado.error }
  end

  # Manda la plantilla de bienvenida si quien está operando lo pidió. Devuelve un aviso para
  # mostrar, o nil.
  #
  # Tres candados, y el orden importa:
  #   1. El rol. Que el dispensador no vea el checkbox es UI; la barrera es esta línea. Un
  #      alta de mostrador la anuncia quien la admite, no quien la carga.
  #   2. El módulo. Sin el add-on de correo el parámetro se ignora en silencio.
  #   3. Que exista una plantilla de bienvenida activa. Si el admin la borró, no hay qué mandar.
  #
  # Nunca hace fallar la operación: el paciente quedó dado de alta o aprobado igual, y que Gmail
  # rechace la contraseña no puede deshacer eso. El problema se informa como aviso.
  def enviar_bienvenida(paciente)
    return unless ActiveModel::Type::Boolean.new.cast(params[:enviar_bienvenida])
    return unless Paciente::ROLES_APRUEBAN.include?(current_user.role)
    return unless current_user.club.feature?('mailer')

    plantilla = current_user.club.plantillas_mail.activas.find_by(bienvenida: true)
    return 'No hay una plantilla de bienvenida activa: el paciente se dio de alta sin mail.' unless plantilla

    resultado = Correo::EnviarAPaciente.call(
      paciente:  paciente,
      usuario:   current_user,
      asunto:    plantilla.asunto_para(paciente),
      cuerpo:    plantilla.cuerpo_para(paciente),
      tipo:      'bienvenida',
      plantilla: plantilla
    )

    resultado.ok? ? nil : "El paciente se guardó, pero el mail de bienvenida no salió: #{resultado.error}"
  end
end
