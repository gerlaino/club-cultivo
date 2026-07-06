class AlertaInterna < ApplicationRecord
  self.table_name = 'alertas_internas'

  belongs_to :club
  acts_as_tenant(:club)
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

  # Entidad a la que apunta la alerta, para el deep-link del panel de notificaciones.
  # Se deriva de `tipo` + `contexto` (+ lote_id). El frontend mapea entidad.tipo → ruta.
  # Devuelve { tipo:, id: } o nil si la alerta no apunta a un recurso navegable.
  ENTIDAD_POR_TIPO = {
    'cosecha_pendiente' => 'lote', 'estado_critico_lote' => 'lote',
    'sin_registro_ambiental' => 'lote', 'ph_fuera_rango' => 'lote', 'ec_fuera_rango' => 'lote',
    'temperatura_fuera_rango' => 'lote', 'humedad_fuera_rango' => 'lote',
    'tarea_vencida_cultivo' => 'tarea',
    'manicura_asignada' => 'lote', 'manicura_aprobada' => 'lote', 'manicura_rechazada' => 'lote',
    'manicura_eliminada' => 'lote', 'manicura_reabierta' => 'lote',
    'manicura_aprobacion_pendiente' => 'manicura',
    'stock_bajo' => 'stock', 'stock_vencimiento' => 'stock',
    'reserva_por_entregar' => 'reserva', 'reserva_vencida' => 'reserva',
    'reprocann_vencido' => 'paciente', 'reprocann_por_vencer' => 'paciente',
    'documento_vencido' => 'paciente', 'saldo_cc_bajo' => 'paciente', 'saldo_gramos_bajo' => 'paciente',
    'indicacion_vencida' => 'paciente', 'indicacion_por_vencer' => 'paciente',
    'paciente_creado_por_dispensador' => 'paciente',
    'delivery_entregado' => 'delivery', 'delivery_fallido' => 'delivery',
  }.freeze

  def entidad
    et = ENTIDAD_POR_TIPO[tipo]
    return nil unless et
    ctx = contexto || {}
    id = case et
         when 'lote', 'manicura' then lote_id || ctx['lote_id']
         when 'tarea'            then ctx['tarea_id']
         when 'reserva'          then ctx['reserva_id']
         when 'paciente'         then ctx['paciente_id']
         when 'stock'            then ctx['sede_id']          # el stock bajo/venc. se ve por sede
         when 'delivery'         then ctx['dispensacion_id']
         end
    { tipo: et, id: id }
  end

  private

  def broadcast_alerta
    payload = { id: id, tipo: tipo, mensaje: mensaje, severidad: severidad,
                destinada_a_role: destinada_a_role, contexto: contexto, entidad: entidad, created_at: created_at }
    ActionCable.server.broadcast("alertas_club_#{club_id}", payload)
    if dirigido_a_user_id = contexto&.dig('dirigido_a_user_id')
      ActionCable.server.broadcast("alertas_user_#{dirigido_a_user_id}", payload)
    end
  rescue StandardError => e
    Rails.logger.warn "AlertaInterna#broadcast_alerta falló: #{e.message}"
  end
end
