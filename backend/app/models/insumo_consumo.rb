# Un consumo de insumo imputado a un lote y/o sala. `costo_imputado_ars` se calcula al
# promedio ponderado del momento del consumo. Es la fuente del costo real de insumos por lote.
class InsumoConsumo < ApplicationRecord
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :insumo
  belongs_to :lote, optional: true
  belongs_to :sala, optional: true
  belongs_to :created_by, class_name: 'User'

  validates :cantidad, numericality: { greater_than: 0 }
  validates :costo_imputado_ars, numericality: { greater_than_or_equal_to: 0 }
end
