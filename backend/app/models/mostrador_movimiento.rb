# Cada subida y cada bajada de la mesa, con quién y por qué.
#
# Sin esto, "hay 300 g" es un número que apareció y nadie sabe de dónde: el admin monitorea a
# distancia, y monitorear sin historial es mirar una foto.
class MostradorMovimiento < ApplicationRecord
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :mostrador_item
  belongs_to :usuario, class_name: 'User'
  # Opcional a propósito: el admin carga la mesa a las 7, cuando todavía no abrió nadie. Cuando
  # SÍ hay turno, queda atado a él para que el arqueo de esa noche sepa qué pasó mientras estaba.
  belongs_to :turno_mostrador, optional: true

  # `carga`/`retiro` los hace el admin sobre la mesa. `dispensa` la baja al entregar y
  # `devolucion` la sube cuando algo vuelve (un reparto que no se entregó, una dispensa
  # revertida). `ajuste` es la corrección del conteo de cierre — y es el ÚNICO que además mueve
  # el inventario real, porque el producto ya no está.
  TIPOS = %w[carga retiro dispensa devolucion ajuste].freeze

  validates :tipo, inclusion: { in: TIPOS }
  validates :cantidad, numericality: { other_than: 0 }
  # Subir y bajar la mesa a mano es una DECISIÓN del admin, y una decisión sin motivo es un
  # número que aparece. Lo automático (dispensar, devolver) no lo pide: su motivo es el hecho.
  validates :motivo, presence: { message: 'hay que decir por qué' }, if: -> { %w[carga retiro ajuste].include?(tipo) }

  scope :recientes, -> { order(created_at: :desc) }
  scope :del_admin, -> { where(tipo: %w[carga retiro]) }
end
