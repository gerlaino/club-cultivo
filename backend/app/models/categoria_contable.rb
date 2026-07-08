# Categoría contable editable por club, jerárquica (madre → subcategoría). Fuente de verdad
# de cara al usuario. `comportamiento` define cómo se comporta el alta de un movimiento con esta
# categoría (general / insumo → depósito / mercaderia → salón). `clave_sistema` es plomería
# interna que mapea a la lógica legacy (aporte_socio, dispensacion, insumo, electricidad…).
#
# Herencia: una subcategoría hereda de su madre la unidad de negocio, la clave de sistema y el
# comportamiento si no los tiene propios (métodos *_efectiva/efectivo).
class CategoriaContable < ApplicationRecord
  self.table_name = 'categorias_contables'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :unidad_negocio, optional: true
  belongs_to :parent, class_name: 'CategoriaContable', optional: true
  has_many :subcategorias, class_name: 'CategoriaContable', foreign_key: :parent_id, dependent: :destroy
  has_many :movimientos_contables, foreign_key: :categoria_contable_id, dependent: :nullify

  TIPOS          = %w[ingreso egreso].freeze
  COMPORTAMIENTOS = %w[general insumo mercaderia].freeze

  validates :nombre, presence: true
  validates :tipo,   presence: true, inclusion: { in: TIPOS }
  validates :comportamiento, inclusion: { in: COMPORTAMIENTOS }
  validate  :parent_coherente

  scope :activas,   -> { where(activa: true) }
  scope :madres,    -> { where(parent_id: nil) }
  scope :hojas,     -> { where.not(parent_id: nil) }
  scope :ingresos,  -> { where(tipo: 'ingreso') }
  scope :egresos,   -> { where(tipo: 'egreso') }
  scope :ordenadas, -> { order(:orden, :nombre) }

  def madre? = parent_id.nil?

  # Valores efectivos (propios o heredados de la madre) — lo que usa el movimiento.
  def unidad_efectiva       = unidad_negocio || parent&.unidad_negocio
  def clave_efectiva        = clave_sistema.presence || parent&.clave_sistema
  def comportamiento_efectivo
    comportamiento != 'general' ? comportamiento : (parent&.comportamiento || 'general')
  end

  private

  # Una madre no puede tener madre (jerarquía de 2 niveles) y la subcategoría hereda el tipo.
  def parent_coherente
    return if parent.nil?

    errors.add(:parent, 'no puede ser una subcategoría (máximo 2 niveles)') if parent.parent_id.present?
    errors.add(:tipo, 'debe coincidir con el de la categoría madre') if parent.tipo != tipo
  end
end
