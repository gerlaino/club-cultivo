# El chat con los pacientes, del lado de la organización (27-oct-2026).
#
#   GET  /mensajes_pacientes                          la bandeja: las conversaciones, primero las que esperan respuesta
#   GET  /pacientes/:id/mensajes                       la conversación con un paciente (lo marca leído)
#   POST /pacientes/:id/mensajes                       contestar (texto y/o adjunto)
#   POST /pacientes/:id/mensajes/resolver              marcarla resuelta (o reabrirla)
#
# La atiende administración (`ConversacionPaciente::ROLES_ATIENDEN`) y sólo con el portal contratado.
class MensajesPacientesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:vista_paciente) }
  before_action :require_atiende!
  before_action :set_paciente, except: :index

  LIMITE = 200

  def index
    convs = ConversacionPaciente.includes(:paciente).where.not(ultimo_mensaje_at: nil)
    convs = convs.sin_responder if params[:filtro] == 'sin_responder'
    if params[:q].present?
      q = "%#{params[:q].to_s.strip}%"
      convs = convs.joins(:paciente).where('pacientes.nombre ILIKE :q OR pacientes.apellido ILIKE :q', q: q)
    end
    convs = convs.order(Arel.sql("CASE WHEN ultimo_autor = 'paciente' AND resuelta_at IS NULL THEN 0 ELSE 1 END"),
                        ultimo_mensaje_at: :desc).limit(200).to_a
    ultimos = MensajePaciente.where(id: MensajePaciente.where(conversacion_id: convs.map(&:id))
                                                       .group(:conversacion_id).select('MAX(id)'))
                             .includes(:user, adjunto_attachment: :blob).index_by(&:conversacion_id)

    render json: {
      data: convs.map { |c| bandeja_json(c, ultimos[c.id]) },
      sin_responder: ConversacionPaciente.sin_responder.count,
    }
  end

  def show
    conv = @paciente.conversacion_portal
    if conv && conv.sin_leer_para_org.positive?
      conv.update_columns(leida_org_at: Time.current)
      conv.avisar!(:leido)
    end
    mensajes = conv ? conv.mensajes.includes(:user, adjunto_attachment: :blob, dispensacion: { items: { stock: :genetica } }).last(LIMITE) : []
    render json: {
      data:         mensajes.map { |m| MensajePacienteSerializer.serialize(m, url_helper: Seguridad::ArchivoPrivado.method(:url)) },
      conversacion: MensajePacienteSerializer.conversacion(conv),
      paciente:     paciente_json(@paciente),
    }
  end

  def create
    conv = ConversacionPaciente.de!(@paciente)
    mensaje = conv.mensajes.new(club: current_user.club, user: current_user, autor: 'organizacion',
                                texto: params[:texto].to_s.strip.presence)
    mensaje.adjunto.attach(params[:adjunto]) if params[:adjunto].present?

    if mensaje.save
      render json: { data: MensajePacienteSerializer.serialize(mensaje, url_helper: Seguridad::ArchivoPrivado.method(:url)) }, status: :created
    else
      render json: { error: mensaje.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def resolver
    conv = ConversacionPaciente.de!(@paciente)
    if conv.resuelta_at
      conv.update!(resuelta_at: nil, resuelta_por: nil)
    else
      conv.update!(resuelta_at: Time.current, resuelta_por: current_user, leida_org_at: Time.current)
    end
    conv.avisar!(:actualizado)
    render json: { conversacion: MensajePacienteSerializer.conversacion(conv) }
  end

  private

  def require_atiende!
    return if ConversacionPaciente::ROLES_ATIENDEN.include?(current_user.role)

    render json: { error: 'El chat con pacientes lo atiende administración.' }, status: :forbidden
  end

  def set_paciente
    @paciente = current_user.club.pacientes.find(params[:id])
  end

  def bandeja_json(c, ultimo)
    p = c.paciente
    {
      paciente:      { id: p.id, nombre: p.nombre, apellido: p.apellido },
      ultimo:        ultimo && {
        autor: ultimo.autor, quien: ultimo.autor == 'organizacion' ? ultimo.user&.first_name : nil,
        texto: ultimo.texto.to_s.truncate(120).presence || (ultimo.adjunto.attached? ? 'Adjuntó un archivo' : ''),
        at: ultimo.created_at,
      },
      sin_leer:      c.sin_leer_para_org,
      sin_responder: c.sin_responder?,
      resuelta:      c.resuelta_at.present?,
    }
  end

  # Lo que el que contesta necesita tener a la vista sin salir del chat. Lista blanca: nada clínico.
  def paciente_json(p)
    cc = p.cuenta_corriente
    ultima = p.dispensaciones.order(fecha_dispensacion: :desc, id: :desc).first
    {
      id: p.id, nombre: p.nombre, apellido: p.apellido,
      reprocann_vencimiento: p.reprocann_vencimiento,
      saldo_cc: cc&.saldo_disponible&.to_f,
      # Subió la renovación del REPROCANN y espera revisión: se revisa desde su ficha.
      renovacion_pendiente: p.reprocann_renovaciones.del_portal.where(estado: 'en_tramite').exists?,
      ultima_dispensa: ultima && { id: ultima.id, fecha: ultima.fecha_dispensacion,
                                   resumen: ultima.items.map { |i| i.genetica_nombre.presence || i.stock&.genetica&.nombre }.compact.join(' + ') },
    }
  end
end
