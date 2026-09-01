# La entrega de la recaudación de un repartidor, con las dos personas adentro.
#
# El repartidor la inicia eligiendo a quién le rinde; el receptor CUENTA y recibe. El monto que
# entra a la caja es el que contó el receptor, siempre: es efectivo, y el que lo tiene en la mano
# es él. Por eso no existe un estado "en disputa" — dejaría plata que no está en ningún lado.
#
# Si el receptor ajustó el monto, queda pendiente la CONFORMIDAD del repartidor. Eso es
# constancia, no candado: la plata ya entró y el circuito ya cerró.
class RendicionCaja < ApplicationRecord
  self.table_name = 'rendiciones_caja'

  include Auditable
  auditar_solo :estado, :monto_declarado_ars, :monto_recibido_ars, :motivo_ajuste, :conforme,
               :receptor_id, :caja_turno_id

  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :delivery,   class_name: 'User'
  belongs_to :receptor,   class_name: 'User', optional: true
  belongs_to :caja_turno, optional: true
  has_many   :cobros, foreign_key: :rendicion_caja_id, dependent: :nullify

  ESTADOS = %w[pendiente recibida anulada].freeze

  validates :estado, inclusion: { in: ESTADOS }
  validates :monto_declarado_ars, numericality: { greater_than_or_equal_to: 0 }
  validates :monto_recibido_ars,  numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :pendientes, -> { where(estado: 'pendiente') }
  scope :recibidas,  -> { where(estado: 'recibida') }
  scope :recientes,  -> { order(rendida_at: :desc) }
  # Lo que el admin mira: se ajustó el monto y el repartidor todavía no dijo si está de acuerdo.
  scope :sin_conformar, -> { recibidas.where(conforme: false) }

  def pendiente? = estado == 'pendiente'
  def recibida?  = estado == 'recibida'

  # Lo que faltó (negativo) o sobró (positivo) respecto de lo que el repartidor había cobrado.
  def diferencia_ars
    return nil if monto_recibido_ars.nil?

    (monto_recibido_ars.to_d - monto_declarado_ars.to_d).round(2)
  end

  def hubo_ajuste? = diferencia_ars.present? && diferencia_ars.nonzero?
end
