# backend/app/models/inventario_movimiento.rb
class InventarioMovimiento < ApplicationRecord
  belongs_to :sede
  belongs_to :club
  belongs_to :sede_inventario
  belongs_to :created_by,    class_name: 'User'
  belongs_to :dispensacion,  optional: true
  belongs_to :lote,          optional: true
  belongs_to :aprobado_por,  class_name: 'User', optional: true

  TIPOS   = %w[ingreso egreso_dispensacion egreso_merma ajuste transferencia].freeze
  ESTADOS = %w[pendiente aprobado rechazado].freeze

  validates :tipo,   inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }
  validates :cantidad, numericality: { other_than: 0 }
  validates :stock_anterior, :stock_nuevo, numericality: { greater_than_or_equal_to: 0 }

  scope :pendientes, -> { where(estado: 'pendiente') }
  scope :aprobados,  -> { where(estado: 'aprobado') }

  def pendiente? = estado == 'pendiente'
  def aprobado?  = estado == 'aprobado'
  def rechazado? = estado == 'rechazado'
end