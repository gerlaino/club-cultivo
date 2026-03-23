# backend/app/models/costo_lote.rb
class CostoLote < ApplicationRecord
  belongs_to :lote
  belongs_to :club
  belongs_to :calculado_por, class_name: "User", optional: true

  validates :costo_total,       numericality: { greater_than_or_equal_to: 0 }
  validates :gramos_producidos, numericality: { greater_than: 0 }, allow_nil: true

  before_save :calcular_costo_total
  before_save :calcular_costo_por_gramo

  def calcular_costo_total
    self.costo_total = [
      costo_insumos.to_d,
      costo_energia.to_d,
      costo_mano_obra.to_d,
      costo_prorrateado.to_d,
    ].sum
  end

  def calcular_costo_por_gramo
    return unless gramos_producidos.to_d > 0
    self.costo_por_gramo = (costo_total / gramos_producidos).round(2)
  end
end