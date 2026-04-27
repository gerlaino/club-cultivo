# backend/app/models/sede_inventario.rb
class SedeInventario < ApplicationRecord
  belongs_to :sede
  belongs_to :club
  belongs_to :created_by, class_name: 'User'
  belongs_to :lote,     optional: true
  belongs_to :genetica, optional: true

  has_many :movimientos,   class_name: 'InventarioMovimiento',
           foreign_key: :sede_inventario_id, dependent: :destroy
  has_many :dispensaciones, foreign_key: :sede_inventario_id, dependent: :nullify

  PRODUCTOS = %w[flores preroll aceite extracto crema otro].freeze
  PRODUCTO_LABELS = {
    'flores'   => 'Flores',
    'preroll'  => 'Preroll',
    'aceite'   => 'Aceite',
    'extracto' => 'Extracto',
    'crema'    => 'Crema',
    'otro'     => 'Otro',
  }.freeze
  PRODUCTO_UNIDAD = {
    'flores'   => 'g',
    'preroll'  => 'u',
    'aceite'   => 'ml',
    'extracto' => 'ml',
    'crema'    => 'g',
    'otro'     => 'u',
  }.freeze

  validates :stock_gramos, numericality: { greater_than_or_equal_to: 0 }
  validates :precio_por_unidad, numericality: { greater_than: 0, allow_nil: true }
  validate  :producto_o_genetica_presente

  def stock_bajo?
    stock_minimo.present? && stock_minimo > 0 && stock_gramos <= stock_minimo
  end

  def producto_efectivo
    genetica ? 'flores' : (producto || 'otro')
  end

  def producto_label
    if genetica
      genetica.nombre
    else
      PRODUCTO_LABELS[producto] || producto
    end
  end

  def unidad_medida
    PRODUCTO_UNIDAD[producto_efectivo] || 'g'
  end

  private

  def producto_o_genetica_presente
    errors.add(:base, 'Debe indicar un producto o una genética') if producto.blank? && genetica_id.blank?
  end
end