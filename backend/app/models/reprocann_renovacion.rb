# Una renovación del REPROCANN de un paciente. Desde el 27-oct-2026 la puede subir el propio
# paciente desde su portal (`origen: 'portal'`, con la constancia adjunta): queda «en revisión»
# (`en_tramite`) hasta que administración la aprueba —y ahí se carga el vencimiento nuevo en la
# ficha— o la rechaza con el motivo, que el paciente ve.
class ReprocannRenovacion < ApplicationRecord
  include Restorable
  self.table_name = 'reprocann_renovaciones'

  ESTADOS = %w[en_tramite aprobada rechazada].freeze
  ORIGENES = %w[organizacion portal].freeze
  TIPOS_CONSTANCIA = %w[image/jpeg image/png image/webp image/heic application/pdf].freeze
  MAX_CONSTANCIA   = 10.megabytes

  belongs_to :paciente
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :iniciada_por, class_name: 'User', optional: true
  belongs_to :revisada_por, class_name: 'User', optional: true
  has_one_attached :constancia

  validates :estado,       inclusion: { in: ESTADOS }
  validates :fecha_inicio, presence: true
  validates :origen,       inclusion: { in: ORIGENES }
  validate  :constancia_valida

  scope :del_portal, -> { where(origen: 'portal') }

  scope :activas,    -> { where(estado: 'en_tramite') }
  scope :recientes,  -> { order(created_at: :desc) }

  # Aprobarla es dejar el REPROCANN del paciente al día: el vencimiento nuevo (y el número, si
  # cambió) y activo. Un vencimiento que ya pasó no es una renovación.
  def aprobar!(reprocann_numero_nuevo: nil, fecha_vencimiento_nueva: nil, por: nil)
    venc = fecha_vencimiento_nueva.is_a?(Date) ? fecha_vencimiento_nueva : (Date.parse(fecha_vencimiento_nueva.to_s) rescue nil)
    if fecha_vencimiento_nueva.present? && (venc.nil? || venc < Time.zone.today)
      errors.add(:fecha_vencimiento_nueva, 'tiene que ser una fecha que todavía no pasó')
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      update!(
        estado:                 'aprobada',
        fecha_aprobacion:       Time.zone.today,
        reprocann_numero_nuevo: reprocann_numero_nuevo,
        fecha_vencimiento_nueva: venc,
        revisada_por:           por,
        revisada_at:            Time.current,
      )
      cambios = {}
      cambios[:reprocann_numero] = reprocann_numero_nuevo if reprocann_numero_nuevo.present?
      if venc
        cambios[:reprocann_vencimiento] = venc
        cambios[:reprocann_estado] = 'activo'
      end
      cambios[:updated_by] = por if por && paciente.respond_to?(:updated_by)
      paciente.update!(cambios) if cambios.any?
    end
  end

  def rechazar!(observaciones: nil, por: nil)
    update!(estado: 'rechazada', observaciones: observaciones, revisada_por: por, revisada_at: Time.current)
  end

  # A la organización: la ficha de ESE paciente se re-pide (el aviso de `pacientes` lleva su id,
  # que es lo que filtra la ficha abierta).
  def avisar_a_la_organizacion!
    Transmite.emitir(club_id, recurso: 'pacientes', accion: 'actualizado', id: paciente_id)
  end

  # Al paciente: le revisaron la constancia que subió. Sin datos en el push (se ve bloqueado).
  def avisar_al_paciente!
    return unless origen == 'portal'

    ActionCable.server.broadcast(PacienteChannel.stream(paciente_id), {
      recurso: 'papeles', accion: estado, id: paciente_id, at: Time.current.iso8601(3),
    })
    return unless paciente.user

    PushNotificationService.notify_user_async(
      paciente.user, title: estado == 'aprobada' ? 'Tu REPROCANN quedó al día' : 'Revisá tu renovación del REPROCANN',
      body: estado == 'aprobada' ? 'Tu organización aprobó la renovación.' : 'Tu organización te dejó un comentario.',
      url: '/portal/mi-salud', tipo: 'renovacion_revisada'
    )
  rescue StandardError => e
    Rails.logger.warn("[renovacion] no se pudo avisar al paciente: #{e.class} #{e.message}")
  end

  private

  def constancia_valida
    return unless constancia.attached?

    errors.add(:constancia, 'tiene que ser una foto o un PDF') unless TIPOS_CONSTANCIA.include?(constancia.blob.content_type)
    errors.add(:constancia, 'pesa más de 10 MB') if constancia.blob.byte_size > MAX_CONSTANCIA
  end
end
