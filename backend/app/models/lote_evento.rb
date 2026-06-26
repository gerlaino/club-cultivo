class LoteEvento < ApplicationRecord
  include Restorable
  belongs_to :lote
  belongs_to :user
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :sala_origen,  class_name: 'Sala', optional: true
  belongs_to :sala_destino, class_name: 'Sala', optional: true

  # cambio_estado: transición de fase (define la historia del lote; no se edita/borra
  # desde el historial). alerta: alerta interna. nota: nota libre legacy. actividad:
  # actividad de cultivo tipada (categoria + metadata) — el caso de backfill.
  TIPOS = %w[cambio_estado nota alerta actividad].freeze

  # Categorías de actividad de cultivo. El trasplante también vive acá (además de su
  # registro por-planta en PlantActivity) para aparecer en el historial unificado.
  CATEGORIAS = %w[riego fertilizacion poda defoliacion tratamiento medicion inspeccion trasplante nota otro].freeze

  CATEGORIA_META = {
    'riego'         => { 'label' => 'Riego',         'emoji' => '💧' },
    'fertilizacion' => { 'label' => 'Fertilización', 'emoji' => '🌿' },
    'poda'          => { 'label' => 'Poda',          'emoji' => '✂️' },
    'defoliacion'   => { 'label' => 'Defoliación',   'emoji' => '🍃' },
    'tratamiento'   => { 'label' => 'Tratamiento',   'emoji' => '🧪' },
    'medicion'      => { 'label' => 'Medición',      'emoji' => '📏' },
    'inspeccion'    => { 'label' => 'Inspección',    'emoji' => '🔍' },
    'trasplante'    => { 'label' => 'Trasplante',    'emoji' => '🪴' },
    'nota'          => { 'label' => 'Nota',          'emoji' => '📝' },
    'otro'          => { 'label' => 'Otro',          'emoji' => '•'  },
  }.freeze

  validates :tipo,          presence: true, inclusion: { in: TIPOS }
  validates :registrado_en, presence: true
  validates :categoria, inclusion: { in: CATEGORIAS }, allow_nil: true
  # Una actividad debe declarar su categoría.
  validates :categoria, presence: true, if: -> { tipo == 'actividad' }

  scope :recientes,    -> { order(registrado_en: :desc) }
  scope :del_lote,     ->(lote_id) { where(lote_id: lote_id) }
  scope :cambios_estado, -> { where(tipo: 'cambio_estado') }
  scope :actividades,    -> { where(tipo: 'actividad') }

  def categoria_meta
    CATEGORIA_META[categoria] || { 'label' => categoria, 'emoji' => '•' }
  end
end