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
  belongs_to :apertura_confirmada_por, class_name: 'User', optional: true
  belongs_to :cierre_solicitado_por,   class_name: 'User', optional: true
  has_many   :bar_ventas, dependent: :nullify

  # abierta → (dispensador confirma apertura) → pendiente_cierre (dispensador envía cierre) → cerrada
  ESTADOS = %w[abierta pendiente_cierre cerrada].freeze

  validates :estado, inclusion: { in: ESTADOS }
  validates :monto_inicial_ars, numericality: { greater_than_or_equal_to: 0 }
  validate  :una_activa_por_bar, on: :create

  scope :abiertas,  -> { where(estado: 'abierta') }
  scope :activas,   -> { where(estado: %w[abierta pendiente_cierre]) } # ocupan el bar
  scope :cerradas,  -> { where(estado: 'cerrada') }
  scope :recientes, -> { order(abierta_at: :desc) }

  def abierta?         = estado == 'abierta'
  def pendiente_cierre? = estado == 'pendiente_cierre'
  def cerrada?         = estado == 'cerrada'
  def activa?          = %w[abierta pendiente_cierre].include?(estado)
  def apertura_confirmada? = apertura_confirmada_at.present?

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

  # El dispensador (o quien opere) confirma que el fondo declarado por el admin está en la caja.
  def confirmar_apertura!(usuario:)
    raise ArgumentError, 'La caja no está abierta' unless abierta?

    update!(apertura_confirmada_por: usuario, apertura_confirmada_at: Time.current)
  end

  # El dispensador cuenta el efectivo y ENVÍA el cierre: queda pendiente de confirmación del admin.
  def solicitar_cierre!(efectivo_declarado:, solicitada_por:, notas: nil)
    raise ArgumentError, 'La caja no está abierta' unless abierta?

    update!(
      estado:                 'pendiente_cierre',
      efectivo_declarado_ars: efectivo_declarado.to_d,
      cierre_solicitado_por:  solicitada_por,
      cierre_solicitado_at:   Time.current,
      notas:                  notas.presence
    )
  end

  # Cierra la caja con el efectivo contado. Sirve para: (a) cierre directo de admin/supervisor
  # (pasa el efectivo), o (b) confirmar el cierre que ya envió el dispensador (efectivo ya cargado).
  def cerrar!(cerrada_por:, efectivo_declarado: nil, notas: nil)
    raise ArgumentError, 'La caja ya está cerrada' if cerrada?

    attrs = { estado: 'cerrada', cerrada_por: cerrada_por, cerrada_at: Time.current }
    attrs[:efectivo_declarado_ars] = efectivo_declarado.to_d unless efectivo_declarado.nil?
    attrs[:notas] = notas if notas.present?
    raise ArgumentError, 'Indicá el efectivo contado' if attrs[:efectivo_declarado_ars].nil? && efectivo_declarado_ars.nil?

    update!(attrs)
  end

  private

  def una_activa_por_bar
    return unless %w[abierta pendiente_cierre].include?(estado)
    return unless CajaTurno.where(bar_id: bar_id, estado: %w[abierta pendiente_cierre]).where.not(id: id).exists?

    errors.add(:base, 'Ya hay una caja activa para este bar')
  end
end
