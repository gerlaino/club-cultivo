class AlertaInterna < ApplicationRecord
  self.table_name = 'alertas_internas'

  belongs_to :club
  belongs_to :creada_por, class_name: 'User', optional: true

  TIPOS      = %w[paciente_creado_por_dispensador documento_vencido reprocann_vencido
                  reprocann_por_vencer
                  manicura_asignada manicura_aprobacion_pendiente manicura_aprobada manicura_rechazada otro].freeze
  SEVERIDADES = %w[info warning error].freeze

  validates :tipo,      inclusion: { in: TIPOS }
  validates :mensaje,   presence: true
  validates :severidad, inclusion: { in: SEVERIDADES }

  scope :no_leidas,     -> { where(leida_at: nil) }
  scope :para_rol,      ->(role) { where(destinada_a_role: role) }
  scope :recientes,     -> { order(created_at: :desc) }

  after_create_commit :broadcast_alerta

  def leida?
    leida_at.present?
  end

  def marcar_leida!
    update!(leida_at: Time.current)
  end

  private

  def broadcast_alerta
    payload = { id: id, tipo: tipo, mensaje: mensaje, severidad: severidad,
                destinada_a_role: destinada_a_role, contexto: contexto, created_at: created_at }
    ActionCable.server.broadcast("alertas_club_#{club_id}", payload)
    if dirigido_a_user_id = contexto&.dig('dirigido_a_user_id')
      ActionCable.server.broadcast("alertas_user_#{dirigido_a_user_id}", payload)
    end
  end
end
