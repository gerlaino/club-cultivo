# Un mensaje del chat del portal (ver `ConversacionPaciente`).
#
# `autor`: quién habla — `paciente` u `organizacion` — y `user` quién lo escribió (del lado de la
# organización se muestra su nombre de pila: «Javier · Raíces»). El texto va CIFRADO: el paciente
# escribe de su salud. Puede citar una dispensa suya y traer un adjunto (una foto o un PDF: la
# constancia del REPROCANN, un comprobante).
class MensajePaciente < ApplicationRecord
  self.table_name = 'mensajes_paciente'

  acts_as_tenant(:club)

  AUTORES   = %w[paciente organizacion].freeze
  MAX_TEXTO = 2_000
  TIPOS_ADJUNTO = %w[image/jpeg image/png image/webp image/heic application/pdf].freeze
  MAX_ADJUNTO   = 10.megabytes

  encrypts :texto

  belongs_to :club
  belongs_to :conversacion, class_name: 'ConversacionPaciente'
  belongs_to :user, optional: true
  belongs_to :dispensacion, optional: true
  has_one_attached :adjunto

  validates :autor, inclusion: { in: AUTORES }
  validates :texto, length: { maximum: MAX_TEXTO }
  validate  :texto_o_adjunto
  validate  :adjunto_valido
  validate  :dispensa_del_mismo_paciente

  after_create_commit :actualizar_conversacion

  private

  def texto_o_adjunto
    errors.add(:base, 'Escribí un mensaje o adjuntá un archivo.') if texto.blank? && !adjunto.attached?
  end

  def adjunto_valido
    return unless adjunto.attached?

    errors.add(:adjunto, 'tiene que ser una foto o un PDF') unless TIPOS_ADJUNTO.include?(adjunto.blob.content_type)
    errors.add(:adjunto, 'pesa más de 10 MB') if adjunto.blob.byte_size > MAX_ADJUNTO
  end

  # Sólo se puede citar una dispensa del mismo paciente: el id viene del cliente.
  def dispensa_del_mismo_paciente
    return if dispensacion_id.blank?

    errors.add(:dispensacion, 'no es de este paciente') unless dispensacion&.paciente_id == conversacion&.paciente_id
  end

  def actualizar_conversacion
    cambios = { ultimo_mensaje_at: created_at, ultimo_autor: autor }
    # Escribir es haber leído lo anterior; y si escribe el paciente, la conversación se reabre.
    if autor == 'paciente'
      cambios.merge!(leida_paciente_at: created_at, resuelta_at: nil, resuelta_por_id: nil)
    else
      cambios[:leida_org_at] = created_at
    end
    conversacion.update_columns(cambios.merge(updated_at: Time.current))
    conversacion.avisar!(:creado)
    avisar_al_otro_lado
  end

  # El aviso al teléfono. Sin el texto: puede tener datos de salud y la notificación se ve con el
  # teléfono bloqueado. Dice quién y lleva a la conversación.
  def avisar_al_otro_lado
    paciente = conversacion.paciente
    if autor == 'paciente'
      PushNotificationService.notify_roles_async(
        club, *ConversacionPaciente::ROLES_ATIENDEN,
        title: "#{paciente.nombre} #{paciente.apellido}".strip + ' te escribió',
        body: 'Mensaje nuevo en el chat con pacientes.', url: "/chat-pacientes?paciente=#{paciente.id}",
        tipo: 'mensaje_paciente'
      )
    elsif paciente.user
      PushNotificationService.notify_user_async(
        paciente.user, title: "#{club.name} te respondió", body: 'Tenés un mensaje nuevo en tu portal.',
        url: '/portal/mensajes', tipo: 'respuesta_organizacion'
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[chat] no se pudo mandar el push: #{e.class} #{e.message}")
  end
end
