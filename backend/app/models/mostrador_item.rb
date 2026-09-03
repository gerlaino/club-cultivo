# UN PRODUCTO SOBRE LA MESA DEL MOSTRADOR, con la cantidad que hay AHORA.
#
# Es el contenido permanente del mostrador, no de un turno: el admin lo carga cuando quiere —a
# las 7 de la mañana, o desde el celular a media tarde— y sigue ahí cuando no hay nadie
# atendiendo. Esa es la diferencia con el modelo anterior, donde abrir el turno ERA poner la
# mercadería: así el admin no podía gobernar la mesa a distancia, que es el punto del módulo.
#
# LA CANTIDAD ESTÁ APARTADA, NO DESCONTADA. `Stock` la resta de su disponible pero la fila del
# stock sigue siendo una sola con su ST-xx y su QR: lo trazable sale del inventario por
# dispensación, nunca por cambiar de estante.
class MostradorItem < ApplicationRecord
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :mostrador
  belongs_to :stock

  has_many :movimientos, class_name: 'MostradorMovimiento', dependent: :destroy

  validates :stock_id, uniqueness: { scope: :mostrador_id }
  validates :cantidad, numericality: { greater_than_or_equal_to: 0 }

  # Lo que se muestra sobre la mesa: un renglón en cero es un pendiente eterno que hay que volver
  # a explicar cada vez que alguien mira. La fila NO se borra —con ella se irían los movimientos
  # que dicen quién lo puso y quién lo sacó— simplemente deja de listarse.
  scope :con_stock, -> { where('cantidad > 0') }

  # Cada cambio de la mesa se avisa por el canal del club: si el admin baja producto desde su
  # oficina, el que atiende lo ve sin recargar.
  after_commit { mostrador&.avisar_cambio }

  # Mover la mesa. TODO cambio pasa por acá y deja su movimiento: "hay 300 g" sin historial es un
  # número que apareció, y monitorear a distancia sin historial es mirar una foto.
  #
  # `cantidad` es FIRMADA: positiva sube, negativa baja.
  def mover!(cantidad:, tipo:, usuario:, motivo: nil, turno: nil)
    delta = cantidad.to_d
    return 0.to_d if delta.zero?

    nueva = self.cantidad.to_d + delta
    raise ArgumentError, "No hay tanto de #{stock&.etiqueta} sobre la mesa" if nueva.negative?

    transaction do
      update!(cantidad: nueva)
      movimientos.create!(club: club, usuario: usuario, tipo: tipo, cantidad: delta,
                          motivo: motivo.presence, turno_mostrador: turno)
    end
    delta
  end

  # EL CONTEO DIJO QUE NO ESTÁ, Y NO ESTÁ: el inventario tiene que reflejarlo.
  #
  # Va como `ajuste` con motivo y NUNCA como `merma` — el informe de Pérdidas cuenta merma, o sea
  # producto destruido, y anotarlo ahí declararía destruido algo que puede estar entero. "No
  # cuadró" y "se pudrió" no son lo mismo, y para un auditor la diferencia importa.
  #
  # Vive acá y no adentro de cada servicio porque lo hacen los DOS conteos que ajustan —el del
  # cierre y el de un producto suelto—, y la misma regla escrita dos veces es de donde salen las
  # divergencias. (El conteo de APERTURA no ajusta: ahí todavía no se sabe si faltó de verdad o
  # si la mesa se cargó de más, y el producto puede estar en el depósito.)
  def ajustar_inventario!(dif, usuario:, concepto:, turno: nil, notas: nil)
    dif = dif.to_d
    return if stock.nil? || dif.zero?

    stock.with_lock do
      stock.update!(cantidad: [stock.cantidad.to_d + dif, 0].max)
      stock.stock_movimientos.create!(
        tipo: 'ajuste', gramos: dif, usuario: usuario, turno_mostrador: turno,
        notas: "#{concepto} — #{dif.negative? ? 'faltante' : 'sobrante'} de " \
               "#{dif.abs.round(3).to_f} #{stock.unidad || 'g'}#{notas.present? ? " — #{notas}" : ''}"
      )
    end
    stock.reload.marcar_agotado_si_vacio!(usuario: usuario)
  end
end
