class StockMovimiento < ApplicationRecord
  include Restorable
  belongs_to :stock
  belongs_to :dispensacion, optional: true
  # El arqueo del mostrador del que salió este ajuste, si salió de uno. Es lo que le permite al
  # informe de Pérdidas decir "esto se perdió en el mostrador" en vez de meterlo en la bolsa de
  # los ajustes.
  belongs_to :turno_mostrador, optional: true
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

  # CUÁNDO PASÓ, que no es cuándo se cargó. Se fechaba con `created_at`, o sea el momento en que
  # alguien se sienta con la computadora: cerrar un stock el jueves y anotarlo el lunes lo ponía
  # en el lunes, y el informe de Pérdidas mostraba la merma en la semana equivocada. Casi todos
  # los movimientos pasan ahora mismo y no la traen; se completa sola para que la columna nunca
  # quede vacía, que es lo que la volvería inservible para cortar por período.
  before_validation { self.fecha ||= (created_at || Time.current).to_date }

  scope :recientes,      -> { order(created_at: :desc) }
  # El corte por período, en un solo lugar. `COALESCE` por los movimientos que el código viejo
  # pudo insertar entre la migración y el deploy: cortarlos afuera sería perder merma real.
  scope :en_periodo,     ->(desde, hasta) {
    where('COALESCE(stock_movimientos.fecha, stock_movimientos.created_at::date) BETWEEN ? AND ?',
          desde.to_date, hasta.to_date)
  }
  scope :de_mostrador,   -> { where.not(turno_mostrador_id: nil) }
  scope :sin_mostrador,  -> { where(turno_mostrador_id: nil) }
end
