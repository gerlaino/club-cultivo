# backend/app/models/movimiento_contable.rb
class MovimientoContable < ApplicationRecord
  include Restorable
  include Auditable

  self.table_name = "movimientos_contables"

  belongs_to :club
  # El turno de caja que lo generó, si salió de ahí: una salida de efectivo o la diferencia
  # del arqueo. Permite volver del libro a la caja que lo explica.
  belongs_to :caja_turno, optional: true
  acts_as_tenant(:club)
  belongs_to :sede,         optional: true
  belongs_to :lote,         optional: true
  belongs_to :dispensacion,  optional: true
  belongs_to :paciente,      optional: true
  belongs_to :compra_cuotas, class_name: 'CompraCuotas', optional: true
  belongs_to :created_by,   class_name: "User"
  # Categoría editable (fuente de verdad de cara al usuario) y unidad de negocio (eje de P&L).
  # Ambas opcionales: los movimientos legacy siguen funcionando con el string `categoria`.
  belongs_to :categoria_contable, optional: true
  belongs_to :unidad_negocio,     optional: true
  belongs_to :evento_bar,         optional: true # dimensión: atribuye el movimiento a un evento

  # Puente legacy ⇄ nuevo: si viene una categoría editable, autocompleta el string `categoria`
  # (que aún dispara aporte_socio / mapeo de costos) y hereda su unidad de negocio.
  before_validation :sincronizar_desde_categoria_contable

  after_create   :acreditar_cuenta_corriente
  before_destroy :revertir_credito_cuenta_corriente
  # El libro es la fuente de verdad de los costos por lote: cualquier cambio
  # en un egreso con lote recalcula su CostoLote (P&L siempre consistente)
  after_commit   :sincronizar_costo_lote, on: [:create, :update, :destroy]

  TIPOS = %w[egreso ingreso recupero_costo ajuste].freeze

  CATEGORIAS = %w[
    insumo electricidad agua alquiler sueldo mantenimiento
    honorario seguro admin aporte_socio dispensacion subvencion bar
    salida_caja retiro_caja diferencia_caja otro
  ].freeze

  CATEGORIA_LABELS = {
    "bar"           => "Bar / Salón",
    "insumo"        => "Insumo / Materia prima",
    "electricidad"  => "Electricidad",
    "agua"          => "Agua",
    "alquiler"      => "Alquiler",
    "sueldo"        => "Sueldo / Honorarios staff",
    "mantenimiento" => "Mantenimiento",
    "honorario"     => "Honorario profesional",
    "seguro"        => "Seguro",
    "admin"         => "Gasto administrativo",
    "aporte_socio"  => "Aporte socio",
    "dispensacion"  => "Recupero dispensación",
    "subvencion"    => "Subvención / Donación",
    # De la caja de turno del mostrador. `salida_caja` es plata que salió del cajón durante el
    # turno; `diferencia_caja` es lo que no apareció (o sobró) al arquear.
    "salida_caja"     => "Gasto pagado con la caja",
    "retiro_caja"     => "Retiro de caja",
    "diferencia_caja" => "Diferencia de caja",
    "otro"          => "Otro",
  }.freeze

  TIPOS_COMPROBANTE = %w[factura_a factura_b recibo ticket sin_comprobante].freeze
  # cuenta_corriente y no_abona llegan desde dispensaciones a crédito (pagado: false)
  MEDIOS_PAGO       = %w[efectivo transferencia mercado_pago cuenta_corriente no_abona].freeze

  # Categorías que típicamente son egresos
  CATEGORIAS_EGRESO = %w[
    insumo electricidad agua alquiler sueldo
    mantenimiento honorario seguro admin
  ].freeze

  # Categorías que típicamente son ingresos
  CATEGORIAS_INGRESO = %w[aporte_socio dispensacion subvencion].freeze

  validates :tipo,        presence: true, inclusion: { in: TIPOS }
  validates :categoria,   presence: true, inclusion: { in: CATEGORIAS }
  validates :descripcion, presence: true
  validates :monto_ars,   presence: true,
            numericality: { greater_than: 0 }
  validates :fecha,       presence: true
  validates :medio_pago,  inclusion: { in: MEDIOS_PAGO }, allow_blank: true
  # La cantidad es opcional (no todo gasto se compra por unidades), pero si viene tiene que ser
  # positiva: un 0 haría explotar el costo unitario y un negativo lo daría al revés.
  validates :cantidad,    numericality: { greater_than: 0 }, allow_nil: true
  # Las cuotas futuras de una compra financiada SÍ pueden tener fecha futura (vencen adelante).
  validate  :fecha_no_futura, unless: :cuota?
  validate  :periodo_no_cerrado, on: [:create, :update]
  before_destroy :verificar_periodo_no_cerrado, prepend: true

  scope :egresos,          -> { where(tipo: %w[egreso]) }
  # Contabilidad de caja: solo cuenta como ingreso la plata que entró de verdad.
  # Las dispensaciones a crédito (pagado: false) son deuda visible, no ingreso.
  scope :ingresos,         -> { where(tipo: %w[ingreso recupero_costo]).where.not(pagado: false) }
  scope :a_credito,        -> { where(tipo: %w[ingreso recupero_costo], pagado: false) }
  scope :del_periodo,      ->(desde, hasta) { where(fecha: desde..hasta) }
  scope :del_mes,          ->(fecha = Time.zone.today) {
    where(fecha: fecha.beginning_of_month..fecha.end_of_month)
  }
  scope :por_sede,         ->(sede_id) { where(sede_id: sede_id) }
  scope :por_lote,         ->(lote_id) { where(lote_id: lote_id) }
  scope :recientes,        -> { order(fecha: :desc, created_at: :desc) }
  # Excluye las cuotas futuras (aún no llegó su mes): son compromisos a futuro, no gastos
  # ocurridos. No afecta a los movimientos normales (sin compra_cuotas_id).
  scope :sin_cuotas_futuras, -> { where('compra_cuotas_id IS NULL OR fecha <= ?', Date.current) }

  def categoria_label
    CATEGORIA_LABELS[categoria] || categoria
  end

  # Categoría, subcategoría y ruta, por separado.
  #
  # El catálogo tiene dos niveles y un movimiento puede colgar de cualquiera de los dos. Cuando
  # cuelga de una subcategoría, `categoria_contable.nombre` es el nombre de la SUB —"Kawsay"—, y
  # mostrarlo como "la categoría" perdía la madre y confundía las dos cosas. Con estos tres la
  # vista elige qué necesita en cada lugar y no vuelve a deducirlo por su cuenta.
  def categoria_madre_nombre
    return nil if categoria_contable.nil?

    (categoria_contable.parent || categoria_contable).nombre
  end

  def subcategoria_nombre
    categoria_contable&.parent_id ? categoria_contable.nombre : nil
  end

  def categoria_ruta
    return nil if categoria_contable.nil?

    [categoria_madre_nombre, subcategoria_nombre].compact.join(' › ')
  end

  def tipo_label
    { "egreso" => "Egreso", "ingreso" => "Ingreso",
      "recupero_costo" => "Recupero de costo", "ajuste" => "Ajuste" }[tipo] || tipo
  end

  # Unidades en las que se compra. `unidad` es libre en la base a propósito (el club puede
  # escribir "bandeja"), esta lista es la que ofrece el formulario.
  UNIDADES = %w[unidad litro mililitro kilogramo gramo bolsa metro hora servicio otro].freeze

  # El precio por unidad, DERIVADO: el monto es el total y la cantidad es cuánto entró. Es el
  # número que sirve para comparar proveedores y el que después alimenta el costo por lote.
  # No se guarda: un unitario persistido queda desfasado apenas se corrige el monto.
  def costo_unitario_ars
    return nil unless cantidad.to_d.positive? && monto_ars.present?

    (monto_ars.to_d / cantidad.to_d).round(2)
  end

  def es_egreso?
    tipo == "egreso"
  end

  def es_ingreso?
    %w[ingreso recupero_costo].include?(tipo)
  end

  # Pertenece a un período contable cerrado por el club (inmutable)
  def cerrado?
    cierre = club&.contabilidad_cerrada_hasta
    cierre.present? && fecha.present? && fecha <= cierre
  end

  # Es una cuota de una compra financiada (puede tener fecha futura).
  def cuota?
    compra_cuotas_id.present?
  end

  private

  # Deriva el string legacy `categoria` y la unidad de negocio desde la categoría editable.
  # No pisa valores ya seteados: un movimiento de sistema (dispensación, cuota) que trae su
  # categoria string explícita queda intacto. Custom sin clave_sistema → 'otro' (válido en el enum).
  def sincronizar_desde_categoria_contable
    return if categoria_contable.nil?

    # Usa los valores EFECTIVOS: si es una subcategoría, hereda clave/unidad de su madre.
    self.categoria         = categoria_contable.clave_efectiva.presence || 'otro' if categoria.blank?
    self.unidad_negocio_id ||= categoria_contable.unidad_efectiva&.id
  end

  def fecha_no_futura
    errors.add(:fecha, "no puede ser futura") if fecha.present? && fecha > Time.zone.today
  end

  # Cierre de período: una vez cerrado un mes, sus movimientos son inmutables.
  # Correcciones sobre períodos cerrados = contra-asiento con fecha actual,
  # o reabrir el período (acción de admin, auditada).
  def periodo_no_cerrado
    cierre = club&.contabilidad_cerrada_hasta
    return if cierre.blank?

    if fecha.present? && fecha <= cierre
      errors.add(:fecha, "pertenece a un período cerrado (hasta el #{cierre.strftime('%d/%m/%Y')})")
    end

    if persisted? && will_save_change_to_fecha? && fecha_was.present? && fecha_was <= cierre
      errors.add(:base, 'No se puede modificar un movimiento de un período cerrado')
    end
  end

  def verificar_periodo_no_cerrado
    return unless cerrado?
    errors.add(:base, 'No se puede eliminar un movimiento de un período cerrado')
    throw :abort
  end

  # Cuando se registra un pago de socio (aporte_socio) vinculado a un paciente,
  # se acredita automáticamente su cuenta corriente.
  def acreditar_cuenta_corriente
    return unless categoria == 'aporte_socio' && paciente_id.present? && monto_ars.to_d > 0

    cc = paciente.cuenta_corriente
    return unless cc

    anterior = cc.saldo_disponible
    nuevo    = anterior + monto_ars.to_d

    ActiveRecord::Base.transaction do
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo:           'pago',
        monto:          monto_ars.to_d,
        saldo_anterior: anterior,
        saldo_nuevo:    nuevo,
        descripcion:    "Pago registrado — Mov. contable ##{id}",
        created_by:     created_by
      )
    end
  rescue => e
    Rails.logger.error "[MovimientoContable] Error al acreditar CC paciente #{paciente_id}: #{e.message}"
    raise
  end

  # Espejo de acreditar_cuenta_corriente: si se elimina un aporte que acreditó
  # la CC del socio, el crédito debe revertirse — si no, el socio conserva
  # crédito por un pago que ya no figura en el libro.
  def revertir_credito_cuenta_corriente
    return unless categoria == 'aporte_socio' && paciente_id.present? && monto_ars.to_d > 0

    cc = paciente&.cuenta_corriente
    return unless cc
    return unless cc.movimientos.where(tipo: 'pago')
                    .where(descripcion: "Pago registrado — Mov. contable ##{id}").exists?

    anterior = cc.saldo_disponible
    nuevo    = anterior - monto_ars.to_d

    ActiveRecord::Base.transaction do
      cc.update!(saldo_disponible: nuevo)
      cc.movimientos.create!(
        tipo:           'ajuste',
        monto:          -monto_ars.to_d,
        saldo_anterior: anterior,
        saldo_nuevo:    nuevo,
        descripcion:    "Reversa por eliminación de pago — Mov. contable ##{id}",
        created_by:     created_by
      )
    end
  rescue => e
    Rails.logger.error "[MovimientoContable] Error al revertir CC paciente #{paciente_id}: #{e.message}"
    raise
  end

  def sincronizar_costo_lote
    lote_ids = [lote_id, previous_changes['lote_id']&.first].compact.uniq
    return if lote_ids.empty?

    lote_ids.each do |id|
      l = Lote.find_by(id: id)
      CostoDesdeLibroService.new(lote: l).call if l
    end
  rescue => e
    # No bloquear la operación contable: el costo se puede recalcular a mano
    Rails.logger.error "[MovimientoContable] Error al sincronizar costo de lote: #{e.message}"
  end
end