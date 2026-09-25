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

  # PARA QUÉ ES (suelo vivo, 25-sep-2026). La receta de siempre es para el agua del riego (y un té
  # que va con el riego también: se dosifica por litro). En una cama de suelo vivo se alimenta la
  # TIERRA: el top dress va por metro cuadrado y la mezcla de armado por litro de suelo. Cada uso
  # admite sólo sus unidades, y pH/EC objetivo sólo tienen sentido en el agua.
  USOS = %w[riego top_dress mezcla].freeze
  USO_LABELS = { 'riego' => 'Riego o té', 'top_dress' => 'Top dress', 'mezcla' => 'Mezcla de armado' }.freeze
  UNIDADES_POR_USO = {
    'riego'     => %w[ml_l g_l],
    'top_dress' => %w[g_m2 ml_m2],
    'mezcla'    => %w[g_l_suelo ml_l_suelo l_l_suelo],
  }.freeze
  # Contra qué se multiplica la dosis al aplicar: litros de agua, m² de cama, litros de suelo.
  BASE_UNIDAD = { 'riego' => 'L', 'top_dress' => 'm²', 'mezcla' => 'L de suelo' }.freeze

  FASES = %w[vegetativo floracion lavado otra].freeze
  FASE_LABELS = { 'vegetativo' => 'Vegetativo', 'floracion' => 'Floración', 'lavado' => 'Lavado', 'otra' => 'Otra' }.freeze

  validates :nombre, presence: true, length: { maximum: 80 }
  validates :fase, inclusion: { in: FASES }, allow_blank: true
  validates :uso,  inclusion: { in: USOS }
  validate  :unidades_del_uso
  validate  :ph_ec_solo_en_riego
  validates :ph_objetivo, numericality: { greater_than: 0, less_than: 14 }, allow_nil: true
  validates :ec_objetivo, numericality: { greater_than_or_equal_to: 0, less_than: 20 }, allow_nil: true
  validate  :al_menos_un_producto

  accepts_nested_attributes_for :receta_items, allow_destroy: true

  scope :activas, -> { where(activa: true) }

  scope :de_uso, ->(uso) { where(uso: uso) }

  # Cuánto de cada producto para N (litros de agua, m² o litros de suelo, según el uso).
  def calcular(litros)
    l = litros.to_d
    receta_items.includes(:insumo).map do |it|
      { insumo_id: it.insumo_id, nombre: it.insumo.nombre, dosis: it.dosis, unidad: it.unidad,
        cantidad: (it.dosis.to_d * l * it.factor_a_insumo).round(3), unidad_insumo: it.insumo.unidad_medida }
    end
  end

  private

  def unidades_del_uso
    permitidas = UNIDADES_POR_USO[uso] || []
    malas = receta_items.reject(&:marked_for_destruction?).reject { |it| permitidas.include?(it.unidad) }
    return if malas.empty?
    errors.add(:base, "Una receta de #{USO_LABELS[uso]&.downcase || uso} se dosifica en " \
                      "#{permitidas.map { |u| RecetaItem::UNIDAD_LABELS[u] }.join(' o ')}")
  end

  def ph_ec_solo_en_riego
    return if uso == 'riego'
    errors.add(:base, 'El pH y la EC objetivo son del agua: sólo van en una receta de riego') if ph_objetivo.present? || ec_objetivo.present?
  end

  def al_menos_un_producto
    vivos = receta_items.reject(&:marked_for_destruction?)
    errors.add(:base, 'Una receta lleva al menos un producto') if vivos.empty?
  end
end
