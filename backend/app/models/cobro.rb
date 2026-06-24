# Una línea de cobro de una dispensación. Una dispensa puede tener varias:
# parte en efectivo, parte en transferencia, y el resto a cuenta corriente (deuda).
#   efectivo / transferencia → pagado: true  (entró plata, es ingreso real)
#   cuenta_corriente         → pagado: false (queda en cuenta del socio, deuda)
# La suma de los cobros nunca debe superar el total (aporte_socio_ars) de la dispensa.
class Cobro < ApplicationRecord
  MEDIOS    = %w[efectivo transferencia cuenta_corriente].freeze
  CONTEXTOS = %w[creacion entrega contabilidad].freeze
  MEDIOS_PAGADOS = %w[efectivo transferencia].freeze

  belongs_to :dispensacion
  belongs_to :club
  belongs_to :created_by, class_name: 'User'

  # Comprobante de la transferencia (foto que sube el delivery/admin). Opcional.
  has_one_attached :comprobante

  validates :medio,     presence: true, inclusion: { in: MEDIOS }
  validates :contexto,  inclusion: { in: CONTEXTOS }
  validates :monto_ars, presence: true, numericality: { greater_than: 0 }

  before_validation :set_pagado_por_medio, on: :create

  scope :pagados,   -> { where(pagado: true) }
  scope :a_credito, -> { where(medio: 'cuenta_corriente') }
  scope :recientes, -> { order(created_at: :desc) }

  def a_credito?
    medio == 'cuenta_corriente'
  end

  private

  def set_pagado_por_medio
    self.pagado = MEDIOS_PAGADOS.include?(medio)
  end
end
