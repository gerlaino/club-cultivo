class PacientesController < ApplicationController
  before_action :authenticate_user!
  before_action :check_pacientes_role!
  before_action :set_paciente, only: [:show, :update, :destroy, :timeline, :subir_reprocann, :eliminar_reprocann, :enviar_mail, :mails_enviados]
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
    orden  = params[:orden].presence_in(%w[created_at nombre apellido]) || "created_at"
    dir    = params[:dir].to_s.downcase == "asc" ? "asc" : "desc"

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
    pacientes = scope.order("#{orden} #{dir}")
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
      meta: { pagina: page, limite: limit, total: total }
    }
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
      descripcion: "Alta como paciente del club",
      id: nil
    }

    render json: { timeline: eventos.sort_by { |e| e[:fecha] }.reverse }
  end

  def create
    unless current_user.admin? || current_user.medico? || current_user.dispensador?
      return render json: { error: 'No autorizado' }, status: :forbidden
    end

    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_paciente?
      info = enforcer.info
      return render json: PlanEnforcer.error_limite('pacientes', info[:limites][:pacientes]), status: :payment_required
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

    if paciente.save
      crear_alerta_dispensador(paciente) if current_user.dispensador?
      render json: { data: paciente }, status: :created
    else
      render json: { errors: paciente.errors.full_messages }, status: :unprocessable_entity
    end
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
    hoy   = Date.today
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
      scope = scope.where('reprocann_vencimiento > ? AND reprocann_vencimiento <= ?', Date.today, 30.days.from_now)
    when 'vencidos'
      scope = scope.where('reprocann_vencimiento < ?', Date.today)
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
              filename:    "pacientes_#{Date.today}.csv",
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
      return render json: { error: 'El club no tiene servidor de correo configurado. Configuralo en Preferencias → Correo.' }, status: :unprocessable_entity
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

  def crear_alerta_dispensador(paciente)
    AlertaInterna.create!(
      club_id:          current_user.club_id,
      tipo:             'paciente_creado_por_dispensador',
      mensaje:          "Dispensador #{current_user.nombre_completo} creó al paciente #{paciente.nombre_completo} sin seguimiento médico",
      severidad:        'info',
      creada_por:       current_user,
      destinada_a_role: 'admin',
      contexto:         { paciente_id: paciente.id, dispensador_id: current_user.id }
    )
  end
end
