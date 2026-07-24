# Categoría de producto del salón (Bebidas, Cocina, Merch…), EDITABLE por el club. Es la
# taxonomía para VENDER (filtros del POS), distinta de la categoría contable (para el P&L) y
# del depósito (dónde vive el stock). Reemplaza al enum hardcodeado BarProducto::CATEGORIAS.
class CategoriaProducto < ApplicationRecord
  self.table_name = 'categorias_producto'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  has_many :bar_productos, dependent: :nullify

  # Defaults que se siembran (clave_sistema ⇄ enum viejo). Editables/renombrables por el club.
  DEFAULTS = { 'bebida' => 'Bebidas', 'cocina' => 'Cocina', 'merch' => 'Merchandising', 'otro' => 'Otros' }.freeze

  validates :nombre, presence: true

  scope :activas,    -> { where(activo: true) }
  scope :ordenadas,  -> { order(:orden, :nombre) }
  scope :sistema,    -> { where(es_sistema: true) }
end
