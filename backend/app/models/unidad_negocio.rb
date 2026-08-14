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

  # Tipos "conocidos" con semántica propia. `social` y `general` quedan sólo por compatibilidad
  # con filas viejas: los que se siembran hoy son los cinco de CANONICOS.
  TIPOS = %w[cultivo dispensario bar social administracion general otro].freeze

  # LOS SECTORES SON ESTOS CINCO Y NO MÁS. Antes el admin podía crear los suyos, y con cada área
  # nueva aparecía otro depósito: terminabas con varios depósitos por sector y sin saber cuál era
  # el bueno. Un sector es un área de la organización —hay cinco— no una etiqueta libre.
  #
  # 'administracion' es el tipo histórico de "General": se conserva para no reescribir las filas
  # existentes ni el mapeo de depósitos (`Deposito::AREA_TIPO_POR_CLAVE`).
  CANONICOS = {
    'administracion' => 'General',
    'cultivo'        => 'Cultivo',
    'dispensario'    => 'Dispensario',
    'bar'            => 'Buffet',
    'otro'           => 'Otro',
  }.freeze

  # Qué sectores tiene cada sede SEGÚN SU TIPO. Una sede de producción no dispensa ni tiene
  # buffet, así que ofrecerle esos sectores es invitar a imputar un gasto a un área que ahí no
  # existe. General y Otro están en todas: toda sede tiene gastos que no son de ningún área.
  TIPOS_POR_SEDE = {
    'produccion' => %w[administracion cultivo otro],
    'social'     => %w[administracion dispensario bar otro],
    'mixta'      => %w[administracion cultivo dispensario bar otro],
  }.freeze

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

  # ¿Este sector existe en esta sede? Un sector desconocido (fila vieja) se deja pasar: esconder
  # datos históricos es peor que mostrar un área de más.
  def aplica_a_sede?(sede)
    return true if sede.nil?

    tipos = TIPOS_POR_SEDE[sede.tipo]
    return true if tipos.nil? || !CANONICOS.key?(tipo)

    tipos.include?(tipo)
  end
end
