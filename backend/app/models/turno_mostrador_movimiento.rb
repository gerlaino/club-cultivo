# Cada carga desde el depósito y cada devolución durante un turno, con hora y autor.
#
# Sin esto, "se repuso" es un número que apareció y nadie sabe quién lo puso — que es justo lo
# que hace inservible delegar el mostrador.
class TurnoMostradorMovimiento < ApplicationRecord
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :turno_mostrador_item
  belongs_to :usuario, class_name: 'User'

  # `correccion` es lo que el que recibe ajusta al confirmar: el admin declaró 300 y sobre la
  # mesa hay 297. NO es una pérdida —los otros 3 siguen en el depósito, nunca salieron de la
  # organización— así que no toca `stocks.cantidad`: sólo corrige el reparto entre mesa y
  # depósito. Por eso es un tipo aparte de `carga` y `devolucion`, que son movimientos queridos.
  TIPOS = %w[carga devolucion correccion].freeze

  validates :tipo,     inclusion: { in: TIPOS }
  # Una corrección puede ser en menos (el admin declaró de más), así que sólo se exige positivo
  # en los movimientos que mueven mercadería a propósito.
  validates :cantidad, numericality: { greater_than: 0 }, unless: -> { tipo == 'correccion' }
  validates :cantidad, numericality: { other_than: 0 },   if:     -> { tipo == 'correccion' }

  scope :cargas,       -> { where(tipo: 'carga') }
  scope :devoluciones, -> { where(tipo: 'devolucion') }
  scope :correcciones, -> { where(tipo: 'correccion') }
  # Lo que el admin tiene que mirar: mercadería sacada del depósito sin nadie que responda.
  scope :sin_supervision, -> { where(sin_supervision: true) }
end
