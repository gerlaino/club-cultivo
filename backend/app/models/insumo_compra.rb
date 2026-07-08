# Una entrada de stock de insumo (compra). El egreso contable asociado (si se generó)
# vive en movimiento_contable. La lógica de costeo está en Insumo#registrar_compra!.
class InsumoCompra < ApplicationRecord
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :insumo
  belongs_to :movimiento_contable, optional: true
  belongs_to :created_by, class_name: 'User'

  validates :cantidad, :costo_total_ars, numericality: { greater_than: 0 }
end
