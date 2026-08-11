class PacientesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  before_action :check_pacientes_role!
  before_action :set_paciente, only: [:show, :update, :destroy, :timeline, :subir_reprocann, :eliminar_reprocann, :enviar_mail, :mails_enviados, :aprobar]
  before_action :require_export_role!, only: [:export_csv]
  before_action :require_criticos_role!, only: [:criticos]
  before_action :normalize_paciente_params, only: [:create, :update]
  before_action :warn_deprecated_route

  # ── ALLOWLIST de campos serializados ──────────────────────────────────────────
  # Campos NO clínicos: visibles para cualquier rol con lectura de la ficha.
  CAMPOS_NO_CLINICOS = %w[
    id club_id nombre apellido dni dni_normalizado fecha_nacimiento es_paciente
    email telefono reprocann_numero reprocann_vencimiento reprocann_estado
    con_seguimiento_medico limite_dispensacion_mensual_g descuento_porcentaje carnet_token
    aprobado_at
    domicilio_calle domicilio_altura domicilio_piso domicilio_depto domicilio_barrio domicilio_ciudad
    envio_calle envio_altura envio_piso envio_depto envio_barrio envio_ciudad
    created_at updated_at
  ].freeze

  # El REPROCANN no es asunto del dispensador. Su regla es más simple y no admite criterio: si el
  # paciente está en la lista, dispensa; si no está, avisa al admin. Mostrarle vencimientos lo pone
  # a decidir sobre un caso que no le toca —y a discutirlo en el mostrador con el paciente
  # enfrente—. Los casos especiales los mira admin/supervisor, que tienen la ficha completa.
  CAMPOS_REPROCANN = %w[reprocann_numero reprocann_vencimiento reprocann_estado].freeze

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
      by_name  = scope.where("lower(nombre) LIKE :q OR lower(apellido) LIKE :q", q: q)
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

    # La LISTA nunca expone datos clínicos: allowlist estricta de campos no clínicos.
    data = pacientes.map do |p|
      p.as_json(only: campos_visibles, methods: metodos_lista)
       .merge('ultima_dispensacion' => ultimas[p.id])
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
    metodos << :reprocann_estado_efectivo unless current_user.dispensador?
    json = @paciente.as_json(only: campos_visibles, methods: metodos)

    # Historia clínica: se agrega SÓLO si el rol puede verla (medico/admin/supervisor).
    if policy(@paciente).ver_notas_clinicas?
      json.merge!(@paciente.as_json(only: CAMPOS_CLINICOS))
    end

    json['reprocann_documento_url'] = url_for(@paciente.reprocann_documento) if @paciente.reprocann_documento.attached?

    ultima = @paciente.dispensaciones.includes(:stock).recientes.first
    json['ultima_dispensacion'] = ultima ? {
      fecha:          ultima.fecha_dispensacion,
      cantidad:       ultima.cantidad,
      forma_producto: ultima.stock&.forma_producto,
    } : nil

    render json: { data: json }
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

    if current_user.dispensador?
      paciente.con_seguimiento_medico = false
    elsif current_user.medico?
      paciente.con_seguimiento_medico = true
    end

    # Quien puede aprobar, aprueba en el mismo acto: para admin y médico dar de alta ES admitir,
    # y pedirles un segundo click sobre su propia alta sería burocracia sin sentido. El
    # mostrador (dispensador, supervisor) carga la solicitud y queda pendiente — el modelo pone
    # la fecha de aprobación salvo que se lo marque así.
    if Paciente::ROLES_APRUEBAN.include?(current_user.role)
      paciente.aprobado_por = current_user
    else
      paciente.desde_mostrador = true
    end

    if paciente.save
      avisar_alta_pendiente(paciente) if paciente.pendiente_aprobacion?
      render json: { data: paciente_json(paciente) }, status: :created
    else
      render json: { errors: paciente.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /pacientes/:id/aprobar — admitir a alguien cargado desde el mostrador.
  def aprobar
    unless Paciente::ROLES_APRUEBAN.include?(current_user.role)
      return render json: { error: 'Sólo un administrador o el médico puede aprobar un alta.' },
                    status: :forbidden
    end

    if @paciente.aprobado?
      return render json: { error: 'Este paciente ya estaba aprobado.' }, status: :unprocessable_entity
    end

    @paciente.aprobar!(current_user)
    render json: { data: paciente_json(@paciente) }
  end

  def update
    if params_include_notas_clinicas? && !can_edit_notas_clinicas?
      return render json: { error: 'No autorizado para modificar notas clínicas' }, status: :forbidden
    end

    raw = params[:paciente] || params[:socio]
    if raw&.key?(:con_seguimiento_medico) && current_user.dispensador?
      return render json: { error: 'No autorizado para modificar seguimiento médico' }, status: :forbidden
    end

    attrs = paciente_params

    @paciente.assign_attributes(attrs)
    @paciente.updated_by = current_user

    if @paciente.save
      render json: { data: @paciente }
    else
      render json: { errors: @paciente.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @paciente.update!(deleted_by_id: current_user.id)
    @paciente.destroy
    head :no_content
  end

  # GET /pacientes/criticos
  def criticos
    hoy   = Time.zone.today
    club  = current_user.club

    reprocann_vencidos = club.pacientes
      .where.not(reprocann_vencimiento: nil)
      .where('reprocann_vencimiento < ?', hoy)
      .where(reprocann_estado: %w[activo pendiente])
      .select(:id, :nombre, :apellido, :reprocann_vencimiento, :reprocann_estado)
      .map { |p| { id: p.id, nombre: p.nombre_completo, reprocann_vencimiento: p.reprocann_vencimiento, dias_vencido: (hoy - p.reprocann_vencimiento).to_i } }

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
      by_name  = scope.where("lower(nombre) LIKE :q OR lower(apellido) LIKE :q", q: q)
      dni_term = params[:query].gsub(/\D/, "")
      scope = dni_term.present? ? by_name.or(scope.where(dni_normalizado: dni_term)) : by_name
    end

    scope = scope.order(apellido: :asc, nombre: :asc)

    require "csv"
    csv_data = CSV.generate(col_sep: ";", encoding: "UTF-8") do |csv|
      csv << [
        "ID", "Apellido", "Nombre", "DNI", "Fecha nacimiento",
        "Email", "Teléfono",
        "N° REPROCANN", "Vencimiento REPROCANN", "Estado REPROCANN",
        "Con seguimiento médico", "Límite dispensación (g/mes)",
        "Registrado"
      ]
      scope.each do |p|
        csv << [
          p.id,
          p.apellido,
          p.nombre,
          p.dni_normalizado,
          p.fecha_nacimiento&.strftime("%d/%m/%Y"),
          p.email,
          p.telefono,
          p.reprocann_numero,
          p.reprocann_vencimiento&.strftime("%d/%m/%Y"),
          p.reprocann_estado,
          p.con_seguimiento_medico ? "Sí" : "No",
          p.limite_dispensacion_mensual_g,
          p.created_at.strftime("%d/%m/%Y"),
        ]
      end
    end

    send_data "\xEF\xBB\xBF#{csv_data}",
              filename:    "pacientes_#{Time.zone.today}.csv",
              type:        "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  # POST /pacientes/:id/enviar_mail
  def enviar_mail
    unless %w[admin supervisor].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    unless @paciente.email.present?
      return render json: { error: 'El paciente no tiene email registrado' }, status: :unprocessable_entity
    end

    unless current_user.club.smtp_configured?
      return render json: { error: 'La organización no tiene servidor de correo configurado. Configuralo en Preferencias → Correo.' }, status: :unprocessable_entity
    end

    tipo   = params.dig(:mail, :tipo).presence_in(MailEnviado::TIPOS) || 'personalizado'
    asunto = params.dig(:mail, :asunto).to_s.strip
    cuerpo = params.dig(:mail, :cuerpo).to_s.strip

    if asunto.blank? || cuerpo.blank?
      return render json: { error: 'El asunto y el cuerpo son obligatorios' }, status: :unprocessable_entity
    end

    mail_record = MailEnviado.new(
      paciente:      @paciente,
      user:          current_user,
      club:          current_user.club,
      asunto:        asunto,
      cuerpo:        cuerpo,
      tipo:          tipo,
      email_destino: @paciente.email,
      enviado_at:    Time.current
    )

    unless mail_record.save
      return render json: { errors: mail_record.errors.full_messages }, status: :unprocessable_entity
    end

    # Envío SINCRÓNICO: es una acción manual que necesita feedback inmediato. Si falla (Gmail
    # rechaza, app-password mal, etc.), el usuario ve el error en el acto en vez de un "enviado"
    # falso (deliver_later lo mandaba a Sidekiq y el error quedaba oculto en el worker).
    begin
      PacienteMailer.mensaje(mail_enviado: mail_record).deliver_now
    rescue => e
      mail_record.destroy
      return render json: { error: "No se pudo enviar el correo: #{e.message}" }, status: :unprocessable_entity
    end

    render json: serialize_mail(mail_record), status: :created
  end

  # GET /pacientes/:id/mails_enviados
  def mails_enviados
    unless %w[admin supervisor].include?(current_user.role)
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    mails = @paciente.mails_enviados.recientes.limit(50).includes(:user)
    render json: mails.map { |m| serialize_mail(m) }
  end

  private

  # Los contadores de la cabecera se cuentan sobre TODO el padrón, no sobre la página.
  # Contarlos en el cliente sobre `store.items` hacía que una organización de 38 pacientes mostrara
  # "20 en la nómina" y "0 REPROCANN vencido" teniendo vencidos en la página 2 — el admin lee
  # ese cero y se queda tranquilo. Mismo criterio que Medico::PacientesController#kpis.
  #
  # Espeja la PRECEDENCIA de `reprocannCategoria` (frontend/src/composables/useReprocann.js):
  # primero el trámite pendiente, después la falta de certificado, y recién ahí la fecha. Si
  # las dos se separan, la tarjeta y la lista que esa tarjeta filtra dejan de coincidir.
  def kpis_padron(scope)
    hoy    = Time.zone.today
    nomina = scope.where(es_paciente: true)

    resto = nomina.where.not(reprocann_estado: 'pendiente')
    # `reprocann_numero` va cifrado (determinístico): admite IS NULL e igualdad, no LIKE.
    # Se suma el estado 'sin_registro' porque una ficha puede quedar sin número cargado o con
    # la baja declarada en el estado, y las dos cuentan como "sin REPROCANN".
    sin_rep = resto.where(reprocann_numero: nil).or(resto.where(reprocann_estado: 'sin_registro'))
    con_rep = resto.where.not(reprocann_numero: nil).where.not(reprocann_estado: 'sin_registro')

    # "No viene hace tiempo": tratamiento abierto pero hace más de 90 días que no retira. El
    # que nunca dispensó NO entra (es un alta reciente, no un abandono), y por eso se cuenta
    # sobre las últimas dispensaciones y no sobre la nómina.
    ultimas   = Dispensacion.no_canceladas
                            .where(paciente_id: nomina.select(:id))
                            .group(:paciente_id).maximum(:fecha_dispensacion)
    inactivos = ultimas.count { |_id, fecha| fecha.present? && fecha < 90.days.ago.to_date }

    {
      total:      nomina.count,
      baja:       scope.where(es_paciente: false).count,
      # Cargados desde el mostrador y todavía sin admitir. Van aparte porque no es un problema
      # del REPROCANN sino del alta, y porque cada uno es alguien que hoy NO puede retirar.
      pendientes_aprobacion: nomina.pendientes_aprobacion.count,
      pendientes: nomina.where(reprocann_estado: 'pendiente').count,
      sin_rep:    sin_rep.count,
      vencidos:   con_rep.where.not(reprocann_vencimiento: nil)
                         .where(reprocann_vencimiento: ...hoy).count,
      proximos:   con_rep.where(reprocann_vencimiento: hoy..(hoy + 30)).count,
      inactivos:  inactivos,
    }
  end

  def campos_visibles
    return CAMPOS_NO_CLINICOS - CAMPOS_REPROCANN if current_user.dispensador?
    CAMPOS_NO_CLINICOS
  end

  def metodos_lista
    return [:nombre_completo] if current_user.dispensador?
    [:nombre_completo, :reprocann_estado_efectivo]
  end


  def serialize_mail(m)
    {
      id:            m.id,
      asunto:        m.asunto,
      cuerpo:        m.cuerpo,
      tipo:          m.tipo,
      email_destino: m.email_destino,
      enviado_at:    m.enviado_at,
      remitente:     m.user.nombre_completo
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
    allowed = %i[nombre apellido dni fecha_nacimiento es_paciente email telefono reprocann_numero reprocann_vencimiento reprocann_estado
                 domicilio_calle domicilio_altura domicilio_piso domicilio_depto domicilio_barrio domicilio_ciudad
                 envio_calle envio_altura envio_piso envio_depto envio_barrio envio_ciudad]
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
end
