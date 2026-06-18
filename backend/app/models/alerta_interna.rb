class AlertaInterna < ApplicationRecord
  self.table_name = 'alertas_internas'

  belongs_to :club
  belongs_to :creada_por, class_name: 'User', optional: true
  belongs_to :lote, optional: true

  TIPOS_OPERATIVOS = %w[
    paciente_creado_por_dispensador documento_vencido reprocann_vencido reprocann_por_vencer
    indicacion_vencida indicacion_por_vencer
    manicura_asignada manicura_aprobacion_pendiente manicura_aprobada manicura_rechazada manicura_eliminada manicura_reabierta
    stock_bajo stock_vencimiento saldo_cc_bajo saldo_gramos_bajo
    delivery_entregado delivery_fallido
    reserva_por_entregar reserva_vencida
    otro
  ].freeze

  TIPOS_CULTIVO = %w[
    sin_registro_ambiental ph_fuera_rango ec_fuera_rango
    temperatura_fuera_rango humedad_fuera_rango
    cosecha_pendiente tarea_vencida_cultivo estado_critico_lote
  ].freeze

  TIPOS       = (TIPOS_OPERATIVOS + TIPOS_CULTIVO).freeze
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
  rescue StandardError => e
    Rails.logger.warn "AlertaInterna#broadcast_alerta falló: #{e.message}"
  end
end
