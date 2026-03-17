# backend/app/models/sede_inventario.rb
class SedeInventario < ApplicationRecord
  belongs_to :sede
  belongs_to :club
  belongs_to :created_by, class_name: 'User'
  belongs_to :lote, optional: true

  has_many :movimientos, class_name: 'InventarioMovimiento',
           foreign_key: :sede_inventario_id, dependent: :destroy

  PRODUCTOS = %w[flores aceite extracto crema otro].freeze
  PRODUCTO_LABELS = {
    'flores'   => 'Flores',
    'aceite'   => 'Aceite',
    'extracto' => 'Extracto',
    'crema'    => 'Crema',
    'otro'     => 'Otro',
  }.freeze

  validates :producto,     inclusion: { in: PRODUCTOS }
  validates :stock_gramos, numericality: { greater_than_or_equal_to: 0 }

  def stock_bajo?
    stock_minimo.present? && stock_minimo > 0 && stock_gramos <= stock_minimo
  end

  def producto_label
    PRODUCTO_LABELS[producto] || producto
  end
end