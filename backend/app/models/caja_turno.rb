# Caja de turno de un PUNTO DE VENTA: una `Barra` (el buffet) o un `Mostrador` (el del
# dispensario). Se abre con un fondo inicial y se cierra con un arqueo: el operador cuenta el
# efectivo y el sistema compara contra lo esperado (fondo + lo cobrado en efectivo en el turno).
#
# Son cajas INDEPENDIENTES: cada punto abre, arquea y cierra la suya y la plata nunca se mezcla.
# Lo que se comparte es la mecánica —admin abre, el operador confirma que el fondo está, el
# operador envía el cierre y el admin lo confirma—, que ya estaba escrita y probada para el bar.
#
# De dónde sale lo cobrado depende del punto, y es la única diferencia real entre las dos:
#   Barra     → `bar_ventas` del turno
#   Mostrador → `cobros` de las dispensaciones del turno (efectivo y transferencia)
#
# Una sola caja activa por punto (índice único parcial + validación).
class CajaTurno < ApplicationRecord
  acts_as_tenant(:club)

  # La caja se audita porque es plata: quién abrió con cuánto, quién confirmó el fondo, quién
  # contó, quién cerró y quién ANULÓ. Las aperturas anuladas no se muestran en pantalla —no
  # operaron, no son un turno— pero el rastro de quién las deshizo tiene que existir para poder
  # dárselo al cliente si lo pide.
  #
  # Allowlist y no denylist: si mañana aparece una columna nueva, entra al rastro sólo si alguien
  # la agrega acá a propósito.
  include Auditable
  auditar_solo :estado, :monto_inicial_ars, :efectivo_declarado_ars, :notas,
               :abierta_por_id, :apertura_confirmada_por_id, :cierre_solicitado_por_id,
               :cerrada_por_id

  belongs_to :club
  # El dueño de la caja. `bar` queda por compatibilidad —lo usan las consultas del Salón y
  # `Barra#caja_abierta`— y es NULL en una caja de mostrador.
  belongs_to :punto, polymorphic: true
  belongs_to :bar,  class_name: 'Barra', optional: true
  belongs_to :sede
  belongs_to :abierta_por, class_name: 'User'
  belongs_to :cerrada_por, class_name: 'User', optional: true
  belongs_to :apertura_confirmada_por, class_name: 'User', optional: true
  belongs_to :cierre_solicitado_por,   class_name: 'User', optional: true
  has_many   :bar_ventas, dependent: :nullify
  has_many   :cobros,     dependent: :nullify
  # Lo que SALIÓ del cajón durante el turno y la diferencia del arqueo: son asientos normales
  # —cuentan en el P&L como cualquier gasto— y además quedan atados al turno.
  # `class_name` explícito: Rails singulariza "movimientos_contables" como "MovimientosContable"
  # y no encuentra la clase. Es la misma trampa de los plurales compuestos que ya mordió en
  # gastos recurrentes.
  has_many   :movimientos_contables, class_name: 'MovimientoContable', dependent: :nullify

  # abierta → (el operador confirma apertura) → pendiente_cierre (el operador envía cierre) → cerrada
  #
  # `anulada` es la salida para el error humano: se abrió la caja por equivocación —mal monto, la
  # sede equivocada, se arrepintió— y hay que deshacerlo. NO es un cierre: cerrar con $0 contado
  # generaría un faltante de arqueo por todo el fondo, un egreso inventado en el libro.
  ESTADOS = %w[abierta pendiente_cierre cerrada anulada].freeze

  # Dónde vive la caja del dispensario. Estaba escrito a mano como `punto_type: 'Sede'` en cinco
  # archivos, y ninguno tiraba error al quedar desactualizado: simplemente no encontraban caja,
  # el cobro quedaba suelto y el arqueo mentía en silencio. Ahora es una constante y dos scopes.
  PUNTO_MOSTRADOR = 'Mostrador'.freeze

  scope :de_mostradores, -> { where(punto_type: PUNTO_MOSTRADOR) }
  scope :del_mostrador,  ->(m) { where(punto_type: PUNTO_MOSTRADOR, punto_id: m) }

  # La caja abierta del mostrador de una sede. Es la MISMA pregunta que hacen el cobro de una
  # dispensa, el saldado de un retiro y la rendición del repartidor, y cada uno la escribía por
  # su cuenta.
  #
  # `unscoped` + club_id explícito, y NO `without_tenant`: estos llamadores corren desde la
  # entrega del repartidor y desde Contabilidad, donde no hay tenant fijado, así que con
  # `require_tenant` la query revienta. Pero `without_tenant` toca estado GLOBAL y se filtra
  # entre ejemplos. `unscoped` es local a la query.
  def self.abierta_en_sede(club_id:, sede_id:)
    return nil if sede_id.nil?

    mostradores = Mostrador.unscoped
                           .where(club_id: club_id, sede_id: sede_id, deleted_at: nil)
                           .select(:id)
    unscoped.where(club_id: club_id, estado: 'abierta').del_mostrador(mostradores).first
  end

  validates :estado, inclusion: { in: ESTADOS }
  validates :monto_inicial_ars, numericality: { greater_than_or_equal_to: 0 }
  validate  :una_activa_por_punto, on: :create

  scope :abiertas,  -> { where(estado: 'abierta') }
  scope :activas,   -> { where(estado: %w[abierta pendiente_cierre]) } # ocupan el bar
  scope :cerradas,  -> { where(estado: 'cerrada') }
  scope :recientes, -> { order(abierta_at: :desc) }

  def abierta?         = estado == 'abierta'
  def pendiente_cierre? = estado == 'pendiente_cierre'
  def cerrada?         = estado == 'cerrada'
  def activa?          = %w[abierta pendiente_cierre].include?(estado)
  def anulada?         = estado == 'anulada'

  # Sólo se anula una caja SIN MOVIMIENTO. Con un cobro adentro ya pasó plata por ahí y la salida
  # es el cierre con su arqueo: anularla borraría el turno de una plata que sí entró.
  def anulable?
    activa? && !cobros.exists? && !movimientos_contables.exists?
  end
  def apertura_confirmada? = apertura_confirmada_at.present?

  # ¿Es la caja del mostrador de dispensa o la del buffet? Cambia de dónde sale lo cobrado.
  def de_dispensario? = punto_type == PUNTO_MOSTRADOR
  def de_bar?         = punto_type == 'Barra'

  # Lo cobrado en el turno. En el buffet son las ventas del mostrador; en el dispensario, los
  # cobros de las dispensaciones. La cuenta corriente NO entra: es una deuda que se registra,
  # no plata que entró al cajón, y sumarla haría que el arqueo diera faltante siempre.
  def total_ventas_ars
    de_dispensario? ? cobros.where(medio: Cobro::MEDIOS_PAGADOS).sum(:monto_ars).to_f
                    : bar_ventas.sum(:total_ars).to_f
  end

  def tickets
    de_dispensario? ? cobros.select(:dispensacion_id).distinct.count : bar_ventas.count
  end

  def total_efectivo_ars
    de_dispensario? ? cobros.where(medio: 'efectivo').sum(:monto_ars).to_f
                    : bar_ventas.where(medio_pago: 'efectivo').sum(:total_ars).to_f
  end

  # Efectivo que se sacó del cajón en el turno. Son DOS cosas distintas y la diferencia es
  # contable, no cosmética:
  #
  #   salida_caja (egreso) — un GASTO pagado con la plata del cajón: un flete, una compra. El
  #     club gastó esa plata: baja el resultado.
  #   retiro_caja (ajuste) — la plata SALIÓ del cajón pero sigue siendo del club, o quedó a
  #     nombre de alguien. "Dame $100.000 de la caja, anotámelos a mí" no es un gasto: asentarlo
  #     como egreso infla los gastos y baja el resultado por plata que nadie gastó. Va como
  #     `ajuste`, que queda afuera de los scopes `ingresos` y `egresos`.
  #
  # Las dos restan del esperado: en las dos, la plata no está en el cajón.
  #
  # Se excluye la diferencia de arqueo, que se asienta al cerrar y no es plata que salió durante
  # el turno sino lo que no apareció al contarlo.
  #
  # Y se excluye lo posterior al CIERRE: el retiro de la recaudación se registra justo después
  # del arqueo, y si contara como salida del turno bajaría lo esperado y la diferencia de arqueo
  # quedaría mal para siempre — un turno que cerró cuadrado aparecería con un sobrante igual a lo
  # que se llevaron. Lo de después del cierre no salió "durante": es la entrega de lo recaudado.
  def salidas
    movs = movimientos_contables.where(categoria: %w[salida_caja retiro_caja])
    cerrada_at.present? ? movs.where(movimientos_contables: { created_at: ...cerrada_at }) : movs
  end

  def total_salidas_ars = salidas.sum(:monto_ars).to_f

  # Plata que ENTRÓ al cajón sin ser una venta: lo que alguien devolvió de un retiro
  # (`devolucion_caja`) y lo que se puso a mano (`ingreso_caja`) — traer cambio, reponer el
  # fondo, dejar lo cobrado por fuera.
  #
  # `saldar_retiro` ya ataba la devolución a la caja abierta con el comentario "la devolución la
  # tiene que esperar el turno que está corriendo", pero el esperado no la sumaba: el turno
  # cerraba con un sobrante igual a lo devuelto. La intención estaba escrita y no implementada.
  #
  # Mismo criterio que `salidas` con el cierre: lo posterior no es del turno.
  def ingresos
    movs = movimientos_contables.where(categoria: %w[devolucion_caja ingreso_caja])
    cerrada_at.present? ? movs.where(movimientos_contables: { created_at: ...cerrada_at }) : movs
  end

  def total_ingresos_ars = ingresos.sum(:monto_ars).to_f

  def total_digital_ars
    (total_ventas_ars - total_efectivo_ars).round(2)
  end

  # Efectivo que debería haber en el cajón: el fondo, más lo cobrado en efectivo, menos lo que
  # se sacó. Es la cuenta que hace quien arquea, escrita igual.
  def efectivo_esperado_ars
    (monto_inicial_ars.to_d + total_efectivo_ars.to_d +
     total_ingresos_ars.to_d - total_salidas_ars.to_d).to_f
  end

  # Lo que QUEDÓ en el cajón después del arqueo: lo contado, menos lo que se retiró al cerrar.
  #
  # Es el fondo que hereda el turno siguiente. Que el que abre a la mañana tenga que declarar con
  # cuánto arranca es justo lo que hace inútil el control: si el número lo pone él, puede poner
  # cualquiera. Heredado, no elige — a lo sumo corrige, y esa corrección queda con su nombre.
  #
  # Los retiros de DURANTE el turno no cuentan acá: esa plata ya salió antes del arqueo y está
  # descontada de lo esperado.
  def fondo_remanente_ars
    return nil unless cerrada? && efectivo_declarado_ars.present?

    retirado = movimientos_contables.where(categoria: 'retiro_caja')
                                    .where(movimientos_contables: { created_at: cerrada_at.. })
                                    .sum(:monto_ars)
    [(efectivo_declarado_ars.to_d - retirado.to_d), 0].max.to_f
  end

  # Diferencia de arqueo (contado − esperado). Solo tiene sentido con la caja cerrada.
  def diferencia_ars
    return nil if efectivo_declarado_ars.nil?

    (efectivo_declarado_ars.to_d - efectivo_esperado_ars.to_d).round(2).to_f
  end

  # El dispensador (o quien opere) confirma que el fondo declarado por el admin está en la caja.
  def confirmar_apertura!(usuario:)
    raise ArgumentError, 'La caja no está abierta' unless abierta?

    update!(apertura_confirmada_por: usuario, apertura_confirmada_at: Time.current)
  end

  # El dispensador cuenta el efectivo y ENVÍA el cierre: queda pendiente de confirmación del admin.
  def solicitar_cierre!(efectivo_declarado:, solicitada_por:, notas: nil)
    raise ArgumentError, 'La caja no está abierta' unless abierta?

    update!(
      estado:                 'pendiente_cierre',
      efectivo_declarado_ars: efectivo_declarado.to_d,
      cierre_solicitado_por:  solicitada_por,
      cierre_solicitado_at:   Time.current,
      notas:                  notas.presence
    )
  end

  # Cierra la caja con el efectivo contado. Sirve para: (a) cierre directo de admin/supervisor
  # (pasa el efectivo), o (b) confirmar el cierre que ya envió el dispensador (efectivo ya cargado).
  def cerrar!(cerrada_por:, efectivo_declarado: nil, notas: nil)
    raise ArgumentError, 'La caja ya está cerrada' if cerrada?

    attrs = { estado: 'cerrada', cerrada_por: cerrada_por, cerrada_at: Time.current }
    attrs[:efectivo_declarado_ars] = efectivo_declarado.to_d unless efectivo_declarado.nil?
    attrs[:notas] = notas if notas.present?
    raise ArgumentError, 'Indicá el efectivo contado' if attrs[:efectivo_declarado_ars].nil? && efectivo_declarado_ars.nil?

    ActiveRecord::Base.transaction do
      update!(attrs)
      asentar_diferencia!(cerrada_por)
    end
  end

  # Un faltante de arqueo es una PÉRDIDA real del club y un sobrante es plata que apareció. Sin
  # asiento, el P&L no se entera nunca de lo que se pierde en el mostrador: quedaba en el
  # historial de cierres y ahí moría.
  #
  # Se asienta al cerrar, con el motivo que escribió quien cierra. Los centavos de redondeo no
  # ensucian el libro.
  def asentar_diferencia!(usuario)
    dif = diferencia_ars
    return if anulada?
    return if dif.nil? || dif.abs < 0.01
    return if movimientos_contables.where(categoria: 'diferencia_caja').exists?

    movimientos_contables.create!(
      club:             club,
      sede_id:          sede_id,
      created_by:       usuario,
      tipo:             dif.negative? ? 'egreso' : 'ingreso',
      categoria:        'diferencia_caja',
      descripcion:      "#{dif.negative? ? 'Faltante' : 'Sobrante'} de caja — #{sede&.nombre} " \
                        "(turno del #{abierta_at&.to_date&.strftime('%d/%m/%Y')})" +
                        (notas.present? ? " — #{notas}" : ''),
      monto_ars:        dif.abs,
      fecha:            (cerrada_at || Time.current).to_date,
      pagado:           true,
      medio_pago:       'efectivo',
      comprobante_tipo: 'sin_comprobante',
    )
  end

  # Deshacer una apertura equivocada. El fondo no se había asentado —abrir no genera asiento— así
  # que no hay nada que revertir en contabilidad: la plata nunca se movió del libro.
  def anular!(usuario:, motivo: nil)
    raise ArgumentError, 'Esta caja ya está cerrada' unless activa?
    unless anulable?
      raise ArgumentError, 'Esta caja ya tiene movimientos: hay que cerrarla con su arqueo, no anularla'
    end

    update!(estado: 'anulada', cerrada_por: usuario, cerrada_at: Time.current,
            notas: motivo.presence || 'Anulada')
  end

  private

  def una_activa_por_punto
    return unless %w[abierta pendiente_cierre].include?(estado)
    return if punto_type.blank? || punto_id.blank?
    return unless CajaTurno.where(punto_type: punto_type, punto_id: punto_id,
                                  estado: %w[abierta pendiente_cierre]).where.not(id: id).exists?

    errors.add(:base, de_dispensario? ? 'Ya hay una caja abierta en este mostrador' : 'Ya hay una caja activa para este bar')
  end
end
