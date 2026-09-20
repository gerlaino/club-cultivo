# Una foto del lote, con lo que hace falta para verla en su línea de tiempo: cuándo se sacó
# (día y semana de vida), en qué fase estaba el lote, de qué planta es (opcional), etiquetas y
# una nota. La imagen vive en Active Storage.
#
# Ver crecer la planta es lo primero que un cultivador de casa compara con cualquier diario
# de cultivo (20-sep-2026): la galería agrupa por semana, filtra por etiqueta y compara dos.
class LoteFoto < ApplicationRecord
  include Transmite
  transmite_como 'fotos'
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :lote
  belongs_to :plant, optional: true
  belongs_to :user,  optional: true

  has_one_attached :imagen

  # Sugeridas en la pantalla; se aceptan otras (la persona escribe la suya y queda para la
  # próxima). Guardadas en minúscula y sin repetir.
  ETIQUETAS_SUGERIDAS = %w[general hoja cogollo raiz problema riego trasplante cosecha].freeze
  ETIQUETA_LABELS = { 'general' => 'General', 'hoja' => 'Hoja', 'cogollo' => 'Cogollo', 'raiz' => 'Raíz',
                      'problema' => 'Problema', 'riego' => 'Riego', 'trasplante' => 'Trasplante', 'cosecha' => 'Cosecha' }.freeze

  validates :tomada_el, presence: true
  validates :nota, length: { maximum: 300 }
  validate  :imagen_presente, on: :create
  validate  :planta_del_lote

  before_validation :defaults
  before_validation :refechar_fase, on: :update

  scope :cronologicas, -> { order(tomada_el: :asc, created_at: :asc) }
  scope :con_etiqueta, ->(e) { where('etiquetas @> ?', [e.to_s].to_json) }

  # Día de vida del lote en que se sacó (1 = el día que arrancó). Nil si el lote no tiene inicio.
  def dia_de_vida
    return nil if lote&.start_date.blank?
    (tomada_el - lote.start_date).to_i + 1
  end

  def semana
    d = dia_de_vida
    d && d >= 1 ? ((d - 1) / 7) + 1 : nil
  end

  def etiquetas=(valor)
    lista = Array(valor).flat_map { |v| v.to_s.split(',') }.map { |e| e.strip.downcase.gsub(/\s+/, '_') }.reject(&:blank?).uniq.first(10)
    super(lista)
  end

  private

  def defaults
    self.tomada_el ||= Time.zone.today
    self.fase      ||= lote&.estado_en(tomada_el)
    self.etiquetas = ['general'] if etiquetas.blank?
  end

  def refechar_fase
    self.fase = lote.estado_en(tomada_el) if will_save_change_to_tomada_el? && !will_save_change_to_fase?
  end

  def imagen_presente
    errors.add(:imagen, 'hace falta la foto') unless imagen.attached?
  end

  def planta_del_lote
    return if plant_id.blank? || lote.nil?
    errors.add(:plant, 'no es de este lote') unless lote.plants.exists?(id: plant_id)
  end
end
