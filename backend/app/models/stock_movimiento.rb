class StockMovimiento < ApplicationRecord
  include Restorable
  belongs_to :stock
  belongs_to :dispensacion, optional: true
  belongs_to :stock_resultante, class_name: 'Stock', optional: true # derivado producido por este mov.
  belongs_to :usuario, class_name: 'User'
  belongs_to :sede_origen,  class_name: 'Sede', optional: true
  belongs_to :sede_destino, class_name: 'Sede', optional: true

  # El stock sale del inventario por `dispensacion` (entrega a un socio, con su trazabilidad) o,
  # cuando se consumió en un evento del salón sin dispensar a nadie identificable (degustación,
  # muestra), por `consumo_evento`. Tipo propio y no `merma` a propósito: no es lo mismo
  # «se consumió en el aniversario» que «se pudrió», y en un informe hay que poder distinguirlo.
  # El apartado para un evento NO genera movimiento: bloquea sin descontar.
  # `salida` es producto que SE FUE ENTERO de la organización: entregado a otro club, vendido o
  # regalado. NO es merma. Distinguirlos importa: el informe de Pérdidas cuenta `merma`, así que
  # anotar una entrega como merma declara destruido algo que está intacto en otro lado — y para
  # un auditor, producto que "se perdió" sin explicación es peor que producto que salió.
  TIPOS = %w[produccion transferencia dispensacion ajuste merma salida consumo_evento].freeze

  validates :tipo,   inclusion: { in: TIPOS }
  validates :gramos, numericality: { other_than: 0 }

  scope :recientes, -> { order(created_at: :desc) }
end
