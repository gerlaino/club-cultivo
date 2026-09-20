# Una receta de nutrientes: qué productos del depósito y cuánto por litro. Se arma una vez y
# se aplica al regar («aplicar receta», ver `Nutricion::Aplicar`). Con pH y EC objetivo
# opcionales, para comparar con lo medido.
#
# Es del club (no de una sede): la receta es conocimiento; el depósito del que se descuenta lo
# decide la sala donde se aplica. Sin plantillas «de fábrica»: cada marca tiene su tabla.
class Receta < ApplicationRecord
  self.table_name = 'recetas'   # el inflector no conoce «receta»: sin esto busca la tabla «receta»
  include Transmite
  transmite_como 'recetas'
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :receta_items, -> { order(:orden, :id) }, dependent: :destroy, inverse_of: :receta
  has_many :insumos, through: :receta_items
  has_many :registros_ambientales, class_name: 'RegistroAmbiental', dependent: :nullify

  FASES = %w[vegetativo floracion lavado otra].freeze
  FASE_LABELS = { 'vegetativo' => 'Vegetativo', 'floracion' => 'Floración', 'lavado' => 'Lavado', 'otra' => 'Otra' }.freeze

  validates :nombre, presence: true, length: { maximum: 80 }
  validates :fase, inclusion: { in: FASES }, allow_blank: true
  validates :ph_objetivo, numericality: { greater_than: 0, less_than: 14 }, allow_nil: true
  validates :ec_objetivo, numericality: { greater_than_or_equal_to: 0, less_than: 20 }, allow_nil: true
  validate  :al_menos_un_producto

  accepts_nested_attributes_for :receta_items, allow_destroy: true

  scope :activas, -> { where(activa: true) }

  # Cuánto de cada producto para N litros.
  def calcular(litros)
    l = litros.to_d
    receta_items.includes(:insumo).map do |it|
      { insumo_id: it.insumo_id, nombre: it.insumo.nombre, dosis: it.dosis, unidad: it.unidad,
        cantidad: (it.dosis.to_d * l).round(2), unidad_insumo: it.insumo.unidad_medida }
    end
  end

  private

  def al_menos_un_producto
    vivos = receta_items.reject(&:marked_for_destruction?)
    errors.add(:base, 'Una receta lleva al menos un producto') if vivos.empty?
  end
end
