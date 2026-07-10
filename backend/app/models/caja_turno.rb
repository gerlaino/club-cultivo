# Caja de turno de un bar/salón. Se abre con un fondo inicial y se cierra con un arqueo:
# el operador cuenta el efectivo y el sistema compara contra lo esperado (fondo + ventas en
# efectivo del turno). Las ventas del turno se enganchan por caja_turno_id. Una sola caja
# abierta por bar a la vez (garantizado por índice único parcial + validación).
class CajaTurno < ApplicationRecord
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :bar,  class_name: 'Barra'
  belongs_to :sede
  belongs_to :abierta_por, class_name: 'User'
  belongs_to :cerrada_por, class_name: 'User', optional: true
  has_many   :bar_ventas, dependent: :nullify

  ESTADOS = %w[abierta cerrada].freeze

  validates :estado, inclusion: { in: ESTADOS }
  validates :monto_inicial_ars, numericality: { greater_than_or_equal_to: 0 }
  validate  :una_abierta_por_bar, on: :create

  scope :abiertas, -> { where(estado: 'abierta') }
  scope :cerradas, -> { where(estado: 'cerrada') }
  scope :recientes, -> { order(abierta_at: :desc) }

  def abierta? = estado == 'abierta'
  def cerrada? = estado == 'cerrada'

  # Ventas del turno (todas si sigue abierta; las enganchadas si ya cerró).
  def total_ventas_ars = bar_ventas.sum(:total_ars).to_f
  def tickets          = bar_ventas.count

  def total_efectivo_ars
    bar_ventas.where(medio_pago: 'efectivo').sum(:total_ars).to_f
  end

  def total_digital_ars
    (total_ventas_ars - total_efectivo_ars).round(2)
  end

  # Efectivo que debería haber en la caja: fondo inicial + ventas cobradas en efectivo.
  def efectivo_esperado_ars
    (monto_inicial_ars.to_d + total_efectivo_ars.to_d).to_f
  end

  # Diferencia de arqueo (contado − esperado). Solo tiene sentido con la caja cerrada.
  def diferencia_ars
    return nil if efectivo_declarado_ars.nil?

    (efectivo_declarado_ars.to_d - efectivo_esperado_ars.to_d).round(2).to_f
  end

  # Cierra la caja con el efectivo contado. Congela el arqueo (esperado/declarado/diferencia
  # quedan implícitos: esperado y diferencia se derivan de las ventas ya enganchadas).
  def cerrar!(efectivo_declarado:, cerrada_por:, notas: nil)
    raise ArgumentError, 'La caja ya está cerrada' unless abierta?

    update!(
      estado:                 'cerrada',
      efectivo_declarado_ars: efectivo_declarado.to_d,
      cerrada_por:            cerrada_por,
      cerrada_at:             Time.current,
      notas:                  notas.presence
    )
  end

  private

  def una_abierta_por_bar
    return unless estado == 'abierta'
    return unless CajaTurno.where(bar_id: bar_id, estado: 'abierta').where.not(id: id).exists?

    errors.add(:base, 'Ya hay una caja abierta para este bar')
  end
end
