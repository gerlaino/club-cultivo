class StockMovimiento < ApplicationRecord
  include Restorable
  belongs_to :stock
  belongs_to :dispensacion, optional: true
  belongs_to :usuario, class_name: 'User'
  belongs_to :sede_origen,  class_name: 'Sede', optional: true
  belongs_to :sede_destino, class_name: 'Sede', optional: true

  TIPOS = %w[produccion transferencia dispensacion ajuste merma].freeze

  validates :tipo,   inclusion: { in: TIPOS }
  validates :gramos, numericality: { other_than: 0 }

  scope :recientes, -> { order(created_at: :desc) }
end
