# Qué plantas recibió un riego del lote, y cuánta agua cada una (Germán, 30-sep-2026: «en
# ciertas plantas 1 pulso, en ciertas otras 2»). La cantidad son LITROS; si se cargó en pulsos,
# quedan también los pulsos y a cuánto equivalía uno (`volumen_l` = pulsos × litros_por_pulso).
# El riego no es de la planta: se registra desde el lote, eligiendo cuáles (`Riegos::PorPlanta`).
class RiegoPlanta < ApplicationRecord
  include Transmite
  transmite_como 'ambiente'
  self.table_name = 'riego_plantas'

  belongs_to :club
  belongs_to :registro_ambiental
  belongs_to :plant
  acts_as_tenant(:club)

  validates :volumen_l,        numericality: { greater_than: 0, less_than: 100_000 }
  validates :pulsos,           numericality: { greater_than: 0 }, allow_nil: true
  validates :litros_por_pulso, numericality: { greater_than: 0 }, allow_nil: true
  validates :plant_id,         uniqueness: { scope: :registro_ambiental_id }
  validate  :pulsos_con_su_equivalencia
  validate  :planta_del_lote

  private

  def pulsos_con_su_equivalencia
    return if pulsos.nil? == litros_por_pulso.nil?
    errors.add(:base, 'Los pulsos van con cuántos litros es un pulso')
  end

  def planta_del_lote
    return if plant.nil? || registro_ambiental.nil? || plant.lote_id == registro_ambiental.lote_id
    errors.add(:plant, 'no es de este lote')
  end
end
