# Un producto de una receta con su dosis por litro. Dosis exacta, en ml/L o g/L (decisión de
# Germán, 20-sep-2026: nada de «tapitas»).
class RecetaItem < ApplicationRecord
  self.table_name = 'receta_items'
  belongs_to :receta, inverse_of: :receta_items
  belongs_to :insumo

  UNIDADES = %w[ml_l g_l].freeze
  UNIDAD_LABELS = { 'ml_l' => 'ml/L', 'g_l' => 'g/L' }.freeze

  validates :dosis,  numericality: { greater_than: 0 }
  validates :unidad, inclusion: { in: UNIDADES }
  validate  :insumo_del_club

  private

  def insumo_del_club
    return if receta.nil? || insumo.nil?
    errors.add(:insumo, 'no es de esta organización') if insumo.club_id != receta.club_id
  end
end
