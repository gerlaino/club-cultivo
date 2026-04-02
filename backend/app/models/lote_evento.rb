class LoteEvento < ApplicationRecord
  belongs_to :lote
  belongs_to :user
  belongs_to :club

  TIPOS = %w[cambio_estado nota alerta].freeze

  validates :tipo,          presence: true, inclusion: { in: TIPOS }
  validates :registrado_en, presence: true

  scope :recientes,    -> { order(registrado_en: :desc) }
  scope :del_lote,     ->(lote_id) { where(lote_id: lote_id) }
  scope :cambios_estado, -> { where(tipo: 'cambio_estado') }
end