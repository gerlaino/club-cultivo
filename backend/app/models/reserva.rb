# Reserva de dispensa: un socio aparta producto para retirar/recibir en una fecha futura.
#
# Es un modelo SEPARADO de Dispensacion a propósito: una reserva no descuenta stock real
# ni mueve plata como una dispensación; sólo BLOQUEA stock (vía Stock#gramos_reservados) y
# opcionalmente registra una seña. Recién al ENTREGARLA se crea la Dispensacion real, que
# corre todas sus validaciones (REPROCANN/crédito/stock) y callbacks financieros.
class Reserva < ApplicationRecord
  include Restorable
  include Auditable # sin campos cifrados → se audita completa (crear/editar/entregar/cancelar)
  ESTADOS          = %w[pendiente entregada cancelada vencida].freeze
  DIAS_VENCIMIENTO = 7 # días posteriores a la fecha de entrega estimada sin retirar → vencida

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :paciente
  # optional: si se borra el stock, la reserva puede quedar huérfana y aún así
  # poder cancelarse/eliminarse sin romper por la FK requerida.
  belongs_to :stock, optional: true
  belongs_to :user
  belongs_to :dispensacion, optional: true

  validates :cantidad,               presence: true, numericality: { greater_than: 0 }
  validates :estado,                 inclusion: { in: ESTADOS }
  validates :fecha_entrega_estimada, presence: true
  validates :sena_ars,               numericality: { greater_than_or_equal_to: 0 }

  validate :stock_pertenece_al_club, on: :create
  validate :stock_disponible,        on: :create
  validate :paciente_activo,         on: :create
  validate :fecha_entrega_futura,    on: :create

  scope :pendientes,    -> { where(estado: 'pendiente') }
  scope :del_paciente,  ->(paciente_id) { where(paciente_id: paciente_id) }
  scope :recientes,     -> { order(fecha_entrega_estimada: :asc, created_at: :desc) }
  # Pendientes cuya fecha de entrega ya pasó hace más de DIAS_VENCIMIENTO días.
  scope :a_vencer, lambda {
    pendientes.where('fecha_entrega_estimada < ?', Date.current - DIAS_VENCIMIENTO)
  }

  def pendiente? = estado == 'pendiente'

  # Lo que falta cobrar al entregar (total estimado menos la seña ya abonada).
  def aporte_restante_ars
    [aporte_estimado_ars.to_d - sena_ars.to_d, 0].max
  end

  def cancelar!(motivo: nil)
    return false unless pendiente?
    update!(estado: 'cancelada', cancelada_at: Time.current,
            notas: [notas, motivo].compact.join(' · ').presence)
  end

  def marcar_vencida!
    return false unless pendiente?
    update!(estado: 'vencida', vencida_at: Time.current)
  end

  private

  # Una reserva aparta stock a futuro: la entrega estimada debe ser a partir de mañana.
  # Hoy (o antes) es una dispensación directa, no una reserva.
  def fecha_entrega_futura
    return if fecha_entrega_estimada.blank?
    if fecha_entrega_estimada <= Date.current
      errors.add(:fecha_entrega_estimada, 'debe ser a partir de mañana (una reserva para hoy es una dispensación)')
    end
  end

  def stock_pertenece_al_club
    return unless stock && paciente
    unless stock.club_id == paciente.club_id || stock.sede&.club_id == paciente.club_id
      errors.add(:stock, 'no pertenece al club')
    end
    errors.add(:stock, 'no está habilitado para dispensa') if stock.persisted? && !stock.apto_dispensa?
  end

  # Valida contra el disponible REAL, que ya descuenta dispensaciones pendientes y otras
  # reservas pendientes (ver Stock#gramos_reservados). Así dos reservas no comprometen el
  # mismo stock.
  def stock_disponible
    return unless stock && cantidad.to_d > 0
    stock.with_lock do
      if cantidad.to_d > stock.cantidad_disponible_real
        errors.add(:cantidad,
          "supera el stock disponible (#{stock.cantidad_disponible_real.round(2)} #{stock.unidad || 'g'} disponibles)")
      end
    end
  end

  def paciente_activo
    return unless paciente
    errors.add(:base, 'El socio no está activo en el club') unless paciente.es_paciente?
  end
end
