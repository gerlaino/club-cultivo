# Cuántos gramos de un pesaje de manicura fueron a cada frasco (Germán, 1-oct-2026: «el admin
# confirma y crea dos frascos, uno de bajos y uno de copones, y pone la cantidad de cada uno»).
# La suma de los destinos de un pesaje es su peso confirmado.
class PesajeDestino < ApplicationRecord
  include Transmite
  transmite_como 'pesajes'
  self.table_name = 'pesaje_destinos'

  belongs_to :club
  belongs_to :pesaje_manicura
  belongs_to :stock
  acts_as_tenant(:club)

  validates :gramos,   numericality: { greater_than: 0 }
  validates :stock_id, uniqueness: { scope: :pesaje_manicura_id }
end
