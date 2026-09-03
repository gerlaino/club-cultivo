# HISTÓRICO. Ya no se escribe: lo reemplazó `MostradorMovimiento`.
#
# Registraba cada carga y cada devolución DE UN TURNO, cuando la mercadería vivía en el turno.
# Desde que la mesa es del mostrador y es permanente, ese rastro es de la mesa y no de la jornada.
#
# La clase se queda porque la tabla todavía tiene las filas de los turnos viejos, y borrarlas es
# tirar el historial de quién puso qué sobre la mesa antes del cambio. Darlas de baja —tabla y
# clase— es una migración aparte, y una decisión de Germán.
#
# NO USAR EN CÓDIGO NUEVO.
class TurnoMostradorMovimiento < ApplicationRecord
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :turno_mostrador_item
  belongs_to :usuario, class_name: 'User'

  # `correccion` es lo que el que recibe ajusta al confirmar: el admin declaró 300 y sobre la
  # mesa hay 297. NO es una pérdida —los otros 3 siguen en el depósito, nunca salieron de la
  # organización— así que no toca `stocks.cantidad`: sólo corrige el reparto entre mesa y
  # depósito. Por eso es un tipo aparte de `carga` y `devolucion`, que son movimientos queridos.
  # `conteo` es contar UN producto sin cerrar el turno. Cerrar y reabrir es el arqueo completo,
  # pero con quince frascos sobre la mesa son veinte minutos y nadie lo hace dos veces por día:
  # el control termina siendo el que no se ejecuta. Contar de a uno cuesta treinta segundos.
  #
  # A diferencia de `correccion` —que ajusta el reparto entre mesa y depósito al recibir— acá la
  # diferencia SÍ es una pérdida real: el producto estaba sobre la mesa y ya no está.
  TIPOS = %w[carga devolucion correccion conteo].freeze

  validates :tipo,     inclusion: { in: TIPOS }
  # Una corrección puede ser en menos (el admin declaró de más), así que sólo se exige positivo
  # en los movimientos que mueven mercadería a propósito.
  SIN_SIGNO = %w[carga devolucion].freeze

  validates :cantidad, numericality: { greater_than: 0 }, if:     -> { SIN_SIGNO.include?(tipo) }
  # Una corrección o un conteo pueden ser en menos: lo que no pueden es ser cero.
  validates :cantidad, numericality: { other_than: 0 },   unless: -> { SIN_SIGNO.include?(tipo) }

  scope :cargas,       -> { where(tipo: 'carga') }
  scope :devoluciones, -> { where(tipo: 'devolucion') }
  scope :correcciones, -> { where(tipo: 'correccion') }
  scope :conteos,      -> { where(tipo: 'conteo') }
  # Lo que el admin tiene que mirar: mercadería sacada del depósito sin nadie que responda.
  scope :sin_supervision, -> { where(sin_supervision: true) }
end
