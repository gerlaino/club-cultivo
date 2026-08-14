# Unidad de negocio: eje analítico del club (cultivo, dispensario, bar, administración…).
# Ortogonal a la sede física: en una sede mixta conviven varias unidades, y cada una
# tiene su propio P&L. Editable por el club; algunas se siembran como `es_sistema`.
class UnidadNegocio < ApplicationRecord
  self.table_name = 'unidades_negocio'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  # OJO: `class_name` explícito. Rails infiere mal el singular de "categorias_contables"
  # (deduce "CategoriasContable", que no existe) → NameError → 500 al tocar la asociación.
  # Mismo problema que ya se corrigió en :movimientos_contables (commit 9a7090b).
  has_many :categorias_contables,  class_name: 'CategoriaContable', dependent: :nullify
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :nullify

  # Tipos "conocidos" con semántica propia (bar/social gatean por feature, y los de sistema
  # emparejan con su depósito). El club puede crear áreas con un tipo libre además de estos:
  # es solo una etiqueta agrupadora, así que no se valida contra la lista.
  TIPOS = %w[cultivo dispensario bar social administracion general].freeze

  validates :nombre, presence: true
  validates :tipo,   presence: true

  scope :activas,    -> { where(activa: true) }
  scope :ordenadas,  -> { order(:orden, :nombre) }

  # Qué pack hace falta para que un sector tenga sentido. Un sector "Cultivo" en una
  # organización que sólo compró dispensa no tiene con qué llenarse: ofrecerlo es invitar a
  # clasificar gastos contra un área que no existe.
  #
  # General / Administración / Otro no dependen de nada: toda organización tiene gastos.
  PACK_REQUERIDO = {
    'cultivo'     => :cultivo,
    'dispensario' => :produccion_dispensa,
    'bar'         => :bar,
    'social'      => :bar,
  }.freeze

  def disponible_para?(club)
    pack = PACK_REQUERIDO[tipo]
    return true if pack.nil?

    club.feature?(pack)
  end
end
