# Producto del bar (café, cerveza, medialuna, merch…). Tiene stock propio que se descuenta
# en cada venta. `costo_ars` es opcional y sirve para calcular el margen.
class BarProducto < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :bar
  belongs_to :unidad_negocio, optional: true
  has_many :bar_venta_items, dependent: :nullify

  CATEGORIAS = %w[bebida cocina merch otro].freeze

  validates :nombre, presence: true
  validates :categoria, inclusion: { in: CATEGORIAS }
  validates :precio_ars, :stock, :stock_minimo, numericality: { greater_than_or_equal_to: 0 }

  scope :activos,    -> { where(activo: true) }
  scope :stock_bajo, -> { where('stock_minimo > 0 AND stock <= stock_minimo') }

  def stock_bajo?
    stock_minimo.to_d.positive? && stock.to_d <= stock_minimo.to_d
  end

  def margen_pct
    return nil if costo_ars.blank? || precio_ars.to_d.zero?

    (((precio_ars.to_d - costo_ars.to_d) / precio_ars.to_d) * 100).round(1)
  end
end
