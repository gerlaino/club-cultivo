# Un producto de una receta con su dosis por litro. Dosis exacta, en ml/L o g/L (decisión de
# Germán, 20-sep-2026: nada de «tapitas»).
class RecetaItem < ApplicationRecord
  self.table_name = 'receta_items'
  belongs_to :receta, inverse_of: :receta_items
  belongs_to :insumo

  # Por litro de agua (riego y tés) · por m² (top dress) · por litro de suelo (mezcla de armado).
  # Qué unidades admite cada receta lo dice `Receta::UNIDADES_POR_USO`.
  UNIDADES = %w[ml_l g_l g_m2 ml_m2 g_l_suelo ml_l_suelo l_l_suelo].freeze
  UNIDAD_LABELS = { 'ml_l' => 'ml/L', 'g_l' => 'g/L', 'g_m2' => 'g/m²', 'ml_m2' => 'ml/m²',
                    'g_l_suelo' => 'g por L de suelo', 'ml_l_suelo' => 'ml por L de suelo',
                    'l_l_suelo' => 'L por L de suelo' }.freeze

  # En qué mide la dosis lo que se pone (el numerador: ml/L → ml; g/m² → g; L por L de suelo → L).
  NUMERADOR = { 'ml_l' => 'mililitro', 'g_l' => 'gramo', 'g_m2' => 'gramo', 'ml_m2' => 'mililitro',
                'g_l_suelo' => 'gramo', 'ml_l_suelo' => 'mililitro', 'l_l_suelo' => 'litro' }.freeze
  # Cuánto de la unidad del insumo es una unidad del numerador. La harina se compra en bolsas de kg
  # y la receta dice g/m²: sin convertir, un top dress de 100 g descontaba 100 KG del depósito. Lo
  # mismo con un fertilizante cargado en litros y una receta en ml/L. Sin equivalencia (g contra
  # litros, unidades sueltas), 1: la cantidad se muestra y se corrige a mano.
  CONVERSION = {
    %w[mililitro litro] => BigDecimal('0.001'), %w[litro mililitro] => BigDecimal('1000'),
    %w[gramo kilogramo] => BigDecimal('0.001'), %w[kilogramo gramo] => BigDecimal('1000'),
  }.freeze

  validates :dosis,  numericality: { greater_than: 0 }
  validates :unidad, inclusion: { in: UNIDADES }
  validate  :insumo_del_club

  def factor_a_insumo
    de = NUMERADOR[unidad]
    a  = insumo&.unidad_medida
    return BigDecimal('1') if de.nil? || a.nil? || de == a
    CONVERSION[[de, a]] || BigDecimal('1')
  end

  private

  def insumo_del_club
    return if receta.nil? || insumo.nil?
    errors.add(:insumo, 'no es de esta organización') if insumo.club_id != receta.club_id
  end
end
