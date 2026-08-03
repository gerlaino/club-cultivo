# backend/app/models/costo_lote.rb
class CostoLote < ApplicationRecord
  include Restorable
  belongs_to :lote
  belongs_to :club
  acts_as_tenant(:club)
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
      # Desprendimientos (ver `Lotes::Desprender`): el gasto queda entero y con su lote original en
      # el libro —un gasto real de $10.000 no son dos de $5.000, no hay dos facturas—, así que el
      # reparto de lo común vive en el costeo. El hijo suma lo que se llevó, el padre resta lo que
      # cedió. Sin esto el padre cargaría plantas que ya no tiene y el hijo saldría gratis.
      lote&.costo_heredado_ars.to_d,
      -lote&.costo_cedido_ars.to_d,
    ].sum
  end

  def calcular_costo_por_gramo
    return unless gramos_producidos.to_d > 0
    self.costo_por_gramo = (costo_total / gramos_producidos).round(2)
  end
end