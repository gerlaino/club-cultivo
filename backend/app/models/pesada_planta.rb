class PesadaPlanta < ApplicationRecord
  self.table_name = 'pesadas_plantas'

  belongs_to :pesada
  belongs_to :plant

  validates :plant_id, uniqueness: { scope: :pesada_id }
  validates :peso_humedo_g, numericality: { greater_than: 0, allow_nil: true }
  validates :peso_seco_g,   numericality: { greater_than: 0, allow_nil: true }
end
