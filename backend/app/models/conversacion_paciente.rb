# El chat de un paciente con su organización: UNA por paciente (ver la migración `CrearChatPacientes`).
#
# Lo que se lee de un vistazo vive acá y no se recalcula de los mensajes en cada lista:
#   · `ultimo_mensaje_at` / `ultimo_autor`: para ordenar la bandeja y saber si espera respuesta;
#   · `leida_org_at` / `leida_paciente_at`: hasta cuándo leyó cada lado (los tildes y los «sin leer»);
#   · `resuelta_at`: la organización la dio por cerrada. Un mensaje nuevo del paciente la reabre.
class ConversacionPaciente < ApplicationRecord
  self.table_name = 'conversaciones_paciente'

  acts_as_tenant(:club)

  # Quién del equipo atiende el chat: administración. El supervisor quedó suspendido para altas
  # nuevas pero los que existen hacen administración, así que también.
  ROLES_ATIENDEN = %w[admin supervisor].freeze

  belongs_to :club
  belongs_to :paciente
  belongs_to :resuelta_por, class_name: 'User', optional: true
  has_many :mensajes, -> { order(:created_at, :id) }, class_name: 'MensajePaciente',
                                                       foreign_key: :conversacion_id, dependent: :destroy

  scope :sin_responder, -> { where(ultimo_autor: 'paciente', resuelta_at: nil) }

  def self.de!(paciente)
    find_or_create_by!(paciente_id: paciente.id) { |c| c.club_id = paciente.club_id }
  rescue ActiveRecord::RecordNotUnique
    find_by!(paciente_id: paciente.id)
  end

  # Espera respuesta de la organización: lo último lo dijo el paciente y nadie la cerró.
  def sin_responder? = ultimo_autor == 'paciente' && resuelta_at.nil?

  def sin_leer_para_org
    mensajes.where(autor: 'paciente').where(leida_org_at ? ['created_at > ?', leida_org_at] : nil).count
  end

  def sin_leer_para_paciente
    mensajes.where(autor: 'organizacion').where(leida_paciente_at ? ['created_at > ?', leida_paciente_at] : nil).count
  end

  # Le avisa a los dos lados que algo cambió, sin datos: cada pantalla re-pide lo suyo (`Transmite`).
  # Al equipo por el canal de la organización; al paciente por el suyo (`PacienteChannel`).
  def avisar!(accion)
    Transmite.emitir(club_id, recurso: 'mensajes', accion: accion, id: paciente_id)
    ActionCable.server.broadcast(PacienteChannel.stream(paciente_id), {
      recurso: 'mensajes', accion: accion.to_s, id: paciente_id, at: Time.current.iso8601(3),
    })
  rescue StandardError => e
    Rails.logger.warn("[chat] no se pudo avisar por el cable: #{e.class} #{e.message}")
  end
end
