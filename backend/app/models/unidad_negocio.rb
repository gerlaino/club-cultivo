# Unidad de negocio: eje analítico del club (cultivo, dispensario, bar, administración…).
# Ortogonal a la sede física: en una sede mixta conviven varias unidades, y cada una
# tiene su propio P&L. Editable por el club; algunas se siembran como `es_sistema`.
class UnidadNegocio < ApplicationRecord
  self.table_name = 'unidades_negocio'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  has_many :categorias_contables,  dependent: :nullify
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :nullify

  TIPOS = %w[cultivo dispensario bar social administracion general].freeze

  validates :nombre, presence: true
  validates :tipo,   presence: true, inclusion: { in: TIPOS }

  scope :activas,    -> { where(activa: true) }
  scope :ordenadas,  -> { order(:orden, :nombre) }

  # Las unidades ligadas a un feature flag del club sólo aplican si está activo.
  # bar/social dependen de feature?(:bar); el resto siempre disponibles.
  def disponible_para?(club)
    return club.feature?(:bar) if %w[bar social].include?(tipo)

    true
  end
end
