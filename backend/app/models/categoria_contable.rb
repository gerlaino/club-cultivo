# Categoría contable editable por club. Es la fuente de verdad de cara al usuario
# (reemplaza al enum MovimientoContable::CATEGORIAS). Las categorías sembradas por el
# sistema llevan `clave_sistema` (aporte_socio, dispensacion, insumo, electricidad…),
# que mapea a la lógica legacy que aún depende del string `categoria` del movimiento.
class CategoriaContable < ApplicationRecord
  self.table_name = 'categorias_contables'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :unidad_negocio, optional: true
  has_many :movimientos_contables, foreign_key: :categoria_contable_id, dependent: :nullify

  TIPOS = %w[ingreso egreso].freeze

  validates :nombre, presence: true
  validates :tipo,   presence: true, inclusion: { in: TIPOS }

  scope :activas,    -> { where(activa: true) }
  scope :ingresos,   -> { where(tipo: 'ingreso') }
  scope :egresos,    -> { where(tipo: 'egreso') }
  scope :ordenadas,  -> { order(:orden, :nombre) }
end
