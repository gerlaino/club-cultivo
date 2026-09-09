# EL TURNO: el arqueo de una jornada de mostrador.
#
# Ya NO es el contenedor de la mercadería —eso es `MostradorItem`, permanente y del mostrador—.
# Acá vive lo que se contó al abrir y lo que se contó al cerrar, con quién lo hizo.
#
# Abrir es CONTAR: quien atiende pesa lo que hay y cuenta la plata, y si no coincide con lo que
# dice el sistema **no se lo bloquea** — pone lo que contó y arranca, y la diferencia queda
# anotada. La "recepción" separada desapareció: era el mismo conteo pedido dos veces.
#
# Cerrar caja es el mismo gesto al revés, y sirve tanto para el arqueo del mediodía como para el
# cambio de turno: cierra uno, abre el otro con lo que dice que hay.
class TurnoMostrador < ApplicationRecord
  acts_as_tenant(:club)

  # Se audita por el mismo motivo que la caja de plata: acá se decide quién abrió, quién recibió,
  # quién cerró y con qué números — y el cierre AJUSTA EL INVENTARIO REAL. La caja se auditaba
  # "porque es plata"; esto mueve mercadería, que es lo mismo con otra unidad.
  #
  # Allowlist: si mañana aparece una columna, entra al rastro sólo si alguien la agrega a
  # propósito.
  include Auditable
  auditar_solo :estado, :abierto_por_id, :cerrado_por_id, :revisado_por_id,
               :notas_apertura, :notas_cierre

  belongs_to :club
  belongs_to :mostrador
  belongs_to :caja_turno,     optional: true
  belongs_to :turno_anterior, class_name: 'TurnoMostrador', optional: true
  belongs_to :abierto_por,  class_name: 'User'
  belongs_to :cerrado_por,  class_name: 'User', optional: true
  belongs_to :revisado_por, class_name: 'User', optional: true

  has_many :items, class_name: 'TurnoMostradorItem', dependent: :destroy

  ESTADOS = %w[abierto cerrado anulado].freeze

  validates :estado, inclusion: { in: ESTADOS }

  scope :abiertos,  -> { where(estado: 'abierto') }
  scope :cerrados,  -> { where(estado: 'cerrado') }
  scope :recientes, -> { order(abierto_at: :desc) }

  # Quedó de la recepción separada, que ya no existe: abrir ES contar. Se mantiene el campo para
  # no perder el rastro de los turnos viejos, pero nada lo pregunta más.
  def operativo? = abierto?

  # Avisar que la mesa cambió. La pantalla del que atiende no se enteraba de que el admin le
  # bajó producto desde su oficina hasta que recargaba — con el paquete ya sobre el mostrador.
  after_commit :avisar_cambio

  def abierto? = estado == 'abierto'
  def cerrado? = estado == 'cerrado'
  def anulado? = estado == 'anulado'

  def revisado? = revisado_at.present?

  # POR QUÉ ESTE CIERRE YA NO SE PUEDE CORREGIR — y vive acá, en UN solo lugar, porque lo
  # preguntan los dos lados: el servicio que corrige y la ficha que ofrece el botón. Escrita dos
  # veces, un día la pantalla invita a corregir algo que el backend rechaza, que es el peor error
  # posible: parece culpa del usuario.
  #
  # Corregir un cierre mueve inventario real y asienta plata en el libro, y hasta acá no tenía
  # NINGUNA frontera temporal: cualquier cierre, para siempre.
  #
  # EL ORDEN IMPORTA: primero el que no tiene arreglo. Decirle «ya está mirado, reabrilo» a un
  # cierre que además tiene una caja posterior lo manda a un callejón sin salida.
  def bloqueo_correccion
    return nil unless cerrado?

    if caja_posterior?
      { motivo: 'caja_posterior',
        texto: 'Después de este cierre se volvió a abrir la caja, y abrir es contar: el producto ' \
               'ya se midió de nuevo. Corregir este conteo lo movería lejos de esa medición, que ' \
               'es la más fresca — la diferencia se arregla en el último cierre.' }
    elsif periodo_cerrado?
      { motivo: 'periodo_cerrado',
        texto: 'Este cierre cae dentro de un período contable cerrado ' \
               "(hasta el #{club.contabilidad_cerrada_hasta.strftime('%d/%m/%Y')}). " \
               'Corregirlo reinterpretaría cantidades ya asentadas: reabrí el período si hay que ' \
               'corregirlo igual.' }
    elsif revisado?
      { motivo: 'visto',
        texto: "Este cierre ya lo miró #{revisado_por&.nombre_completo || 'administración'}" \
               "#{revisado_at ? " el #{revisado_at.in_time_zone.strftime('%d/%m/%Y')}" : ''}. " \
               'Para corregirlo hay que reabrirlo para revisión.' }
    end
  end

  # SE ABRIÓ OTRA CAJA DESPUÉS. No es una regla que decidimos: es que la corrección deja de ser
  # correcta. El conteo del cierre YA ajustó el inventario; si alguien volvió a abrir —y abrir es
  # contar— el stock se re-midió, y aplicarle ahora un delta viejo lo aleja de la última medición
  # real. Las anuladas no cuentan: nunca hubo turno, y su conteo se borra con él.
  def caja_posterior?
    return false if cerrado_at.blank?

    mostrador.turno_mostradores.where.not(id: id).where.not(estado: 'anulado')
             .where(abierto_at: (cerrado_at..)).exists?
  end

  # El ejercicio ya presentado. `CorregirCierre` asienta un movimiento de `diferencia_caja` y
  # mueve stock: sin esto se podía corregir un cierre de un período cerrado — la plata reventaba
  # con el mensaje de validación del movimiento (y hacía rollback de todo), pero los gramos solos
  # pasaban lisos. Mismo candado que cambiar la forma de un producto ya dispensado.
  def periodo_cerrado?
    hasta = club&.contabilidad_cerrada_hasta
    hasta.present? && cerrado_at.present? && cerrado_at.to_date <= hasta
  end

  delegate :sede, :sede_id, to: :mostrador

  # Se usa el canal del club, que ya existe: es la misma conexión y el mismo alcance. Un fallo
  # de ActionCable no puede tumbar una apertura ni un cierre, así que va con rescue.
  def avisar_cambio
    ActionCable.server.broadcast("stocks_club_#{club_id}", {
      tipo: 'mostrador_actualizado', mostrador_id: mostrador_id, sede_id: sede_id,
    })
  rescue => e
    Rails.logger.warn "TurnoMostrador#avisar_cambio falló: #{e.message}"
  end
end
