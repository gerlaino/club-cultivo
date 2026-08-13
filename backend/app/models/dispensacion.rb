class Dispensacion < ApplicationRecord
  include Restorable
  include Auditable
  self.table_name = 'dispensaciones'

  # dispensaciones no tiene columna club_id (no es acts_as_tenant): lo deriva del paciente
  # (paciente_id es NOT NULL). Lo necesita el concern Auditable para el rastro.
  def club_id = paciente&.club_id

  ESTADOS_ENVIO = %w[pendiente en_viaje entregado fallido cancelada].freeze
  MEDIOS_PAGO   = %w[efectivo transferencia cuenta_corriente no_abona credito_gramos mixto regalo].freeze

  belongs_to :paciente
  belongs_to :user
  belongs_to :indicacion_medica, optional: true
  belongs_to :stock
  belongs_to :sede,          optional: true
  belongs_to :delivery_user, class_name: 'User', foreign_key: :delivery_id, optional: true
  belongs_to :ruta_entrega,  optional: true

  # Líneas de la dispensación: cada una es un stock + cantidad (con precio/costo/trazabilidad
  # propios). Una dispensa puede abarcar varios stocks. En la transición conviven con las
  # columnas stock_id/cantidad de `dispensaciones` (mirror de la primera línea).
  has_many :items, class_name: 'DispensacionItem', dependent: :destroy
  has_many :resenas, class_name: 'ResenaProducto', dependent: :destroy
  accepts_nested_attributes_for :items, reject_if: ->(a) { a[:stock_id].blank? && a[:cantidad].to_d <= 0 }

  # Los asientos contables de la dispensación viven y mueren con ella. Puede haber
  # más de uno cuando se paga parte con crédito (deuda) y parte en efectivo (ingreso).
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :destroy

  # Líneas de cobro (efectivo/transferencia/cuenta_corriente). Una dispensa puede tener
  # varias: pagos partidos, parcial, o el resto a cuenta corriente. Ver Cobro.
  has_many :cobros, dependent: :destroy

  # Foto opcional que sube el delivery como prueba de la entrega (distinta del
  # comprobante de pago, que vive en el Cobro de transferencia).
  has_one_attached :comprobante_entrega

  # --- Lectura derivada de líneas (preferida; cae al legacy si todavía no hay líneas) ---

  # Cantidad total dispensada sumando todas las líneas.
  def cantidad_total
    items.exists? ? items.sum(:cantidad).to_d : cantidad.to_d
  end

  # ¿La dispensa abarca más de un stock?
  def multi_stock?
    items.where.not(stock_id: nil).distinct.count(:stock_id) > 1
  end

  # ¿Esta dispensa usa el flujo de cobros? (vs. legacy: asentada por medio_pago único,
  # gramos, etc.). Una legacy ya está saldada por sus movimientos, no por cobros.
  def usa_cobros?
    cobrar_en_entrega? || cobros.exists?
  end

  # Total efectivamente asignado a cobros (pagados + lo que quedó a cuenta corriente).
  def total_cobrado
    cobros.sum(:monto_ars).to_d
  end

  # Monto del total que todavía no se asignó a ningún cobro (crudo, sin el guard
  # legacy). Lo usa el motor de cobros para saber cuánto falta asignar.
  def monto_sin_cobrar
    (aporte_socio_ars.to_d - total_cobrado).round(2)
  end

  # Lo que falta cobrar/asignar. > 0 = pendiente (contra-entrega o cobro parcial).
  # Las dispensas legacy (sin cobros) se consideran saldadas → 0.
  def saldo_pendiente
    return 0.to_d unless usa_cobros?
    (aporte_socio_ars.to_d - total_cobrado).round(2)
  end

  def cobro_completo?
    saldo_pendiente <= 0
  end

  MEDIOS_A_CREDITO = %w[cuenta_corriente no_abona].freeze

  def a_credito?
    MEDIOS_A_CREDITO.include?(medio_pago)
  end

  # Dirección limpia para Google Maps (sin piso/depto, que confunden el geocoding).
  def direccion_envio_maps
    limpia = [[envio_calle, envio_altura].reject(&:blank?).join(' ').presence,
              envio_barrio.presence, envio_ciudad.presence].compact.join(', ')
    limpia.presence || direccion_envio
  end

  before_validation { self.fecha_dispensacion ||= Date.current }
  before_validation :sincronizar_mirror_desde_items, if: :lineas_explicitas?
  before_validation :componer_direccion_envio, if: :con_envio?
  before_create     :generar_codigo_paquete, if: :con_envio?
  before_create     :capturar_snapshot_trazabilidad
  before_create     :generar_token
  before_create     :capturar_snapshot_producto

  validates :cantidad,           presence: true, numericality: { greater_than: 0 }
  validates :fecha_dispensacion, presence: true
  validates :estado_envio,       inclusion: { in: ESTADOS_ENVIO }, allow_nil: true
  validates :medio_pago,         inclusion: { in: MEDIOS_PAGO }, allow_blank: true
  validate  :fecha_no_futura
  validate  :paciente_activo_como_socio, on: :create
  validate  :stock_pertenece_al_club,    on: :create, unless: :lineas_explicitas?
  validate  :stock_disponible,           on: :create, unless: :lineas_explicitas?
  validate  :lineas_validas,             on: :create, if:     :lineas_explicitas?
  validate  :limite_mensual_no_superado, on: :create
  validate  :credito_suficiente,        on: :create, if: -> { medio_pago == 'cuenta_corriente' }
  validate  :credito_no_abona,          on: :create, if: -> { medio_pago == 'no_abona' }
  validate  :gramos_suficientes,        on: :create, if: -> { medio_pago == 'credito_gramos' }
  # Solo al crear: los campos de envío se exigen al generar el despacho, no en cada
  # update. Si no, marcar 'entregado'/'fallido' (que re-guarda) podía romper con 422
  # cuando un despacho viejo tenía algún campo de envío vacío.
  validate  :delivery_fields_presentes, on: :create, if: :con_envio?
  validate  :delivery_contratado,       on: :create, if: :con_envio?

  # Una dispensación cancelada conserva su registro e historia, pero NO cuenta como
  # dispensada (se revirtió stock y plata). Excluila de todo agregado de cantidad/conteo.
  # OJO: estado_envio es NULL en dispensaciones sin envío (la mayoría). where.not las
  # excluiría, así que incluimos explícitamente los NULL.
  scope :no_canceladas,  ->                     { where("dispensaciones.estado_envio IS NULL OR dispensaciones.estado_envio != 'cancelada'") }
  def cancelada? = estado_envio == 'cancelada'

  scope :del_mes,        ->(fecha = Time.zone.today) { where(fecha_dispensacion: fecha.beginning_of_month..fecha.end_of_month) }
  scope :del_paciente,   ->(paciente_id)        { where(paciente_id: paciente_id) }
  scope :regalos,        ->                     { where(es_regalo: true) }
  scope :recientes,      ->                     { order(fecha_dispensacion: :desc, created_at: :desc) }
  scope :con_envio,      ->                     { where(con_envio: true) }
  scope :del_delivery,   ->(user_id)            { where(delivery_id: user_id) }
  scope :estado_envio,   ->(estado)             { where(estado_envio: estado) }
  scope :pendientes_envio, ->                   { con_envio.where(estado_envio: 'pendiente') }
  scope :en_viaje,       ->                     { con_envio.where(estado_envio: 'en_viaje') }

  # Despachos que comparten "ruta" con este, para evaluar el orden de entrega.
  # Si el despacho tiene ruta_id, el grupo es esa ruta; si no (nunca se reordenó),
  # el grupo son los despachos sueltos (ruta_id NULL) del mismo delivery.
  scope :del_grupo_ruta, ->(d) {
    base = del_delivery(d.delivery_id)
    d.ruta_entrega_id.present? ? base.where(ruta_entrega_id: d.ruta_entrega_id) : base.where(ruta_entrega_id: nil)
  }

  # El primer despacho EN CAMINO del grupo, según el orden de la ruta. Es el único
  # que el delivery puede cerrar (entregar/fallar): mientras esté arriba en la ruta
  # otro despacho en camino sin resolver, no se puede saltear. Los pendientes que
  # todavía no arrancaron el viaje no cuentan (no están en esta vuelta).
  def self.siguiente_de_ruta(d)
    del_grupo_ruta(d)
      .where(estado_envio: 'en_viaje')
      .order(Arel.sql('orden_entrega NULLS LAST, created_at ASC'))
      .first
  end

  # ¿Este despacho es el siguiente que toca cerrar en su ruta?
  def siguiente_en_ruta?
    sig = self.class.siguiente_de_ruta(self)
    sig.nil? || sig.id == id
  end

  after_create        :asegurar_item_espejo
  after_create        :decrementar_stock
  after_create_commit :encolar_reporte_ariccame
  after_create_commit :dispatch_webhook
  after_create_commit :broadcast_stock_actualizado
  after_update_commit :broadcast_stock_actualizado, if: :estado_envio_changed?
  after_commit        :notificar_delivery, on: [:update]
  after_destroy       :incrementar_stock

  private

  def fecha_no_futura
    errors.add(:fecha_dispensacion, 'no puede ser futura') if fecha_dispensacion.present? && fecha_dispensacion > Time.zone.today
  end

  def paciente_activo_como_socio
    return unless paciente
    errors.add(:base, 'El socio no está activo en la organización') unless paciente.es_paciente?

    # Un paciente cargado en el mostrador todavía no está admitido. Se valida acá y no sólo en
    # la pantalla porque es el punto por el que pasa TODA entrega —el modal, la conversión de
    # una reserva, la API— y dejarlo en la UI sería tener la regla dibujada, no aplicada.
    return if paciente.aprobado?

    errors.add(:base, "#{paciente.nombre_completo} está pendiente de aprobación: " \
                      'un administrador o el médico tiene que aprobarlo antes de dispensarle.')
  end

  # Despachar exige tener Delivery contratado. Va en el modelo por el mismo motivo que la
  # aprobación del paciente: es el punto por el que pasa toda dispensa con envío, y el candado
  # del controller sólo cubre las pantallas de reparto — el envío se marca al CREAR la
  # dispensación, que es un endpoint de la suite. Sin esto, apagar Delivery dejaba el checkbox
  # "con envío" funcionando y generando paquetes que nadie puede repartir.
  def delivery_contratado
    club = paciente&.club
    return if club.nil? || club.feature?('delivery')

    errors.add(:base, 'El módulo Delivery no está contratado: la dispensación no puede salir con envío.')
  end

  def stock_pertenece_al_club
    return unless stock && paciente
    club_id = paciente.club_id
    unless stock.club_id == club_id || stock.sede&.club_id == club_id
      errors.add(:stock, 'no pertenece a la organización')
    end
    errors.add(:stock, 'no está habilitado para dispensa') if stock.persisted? && !stock.apto_dispensa?
  end

  def stock_disponible
    return unless stock && cantidad.to_d > 0
    stock.with_lock do
      if cantidad.to_d > stock.cantidad_disponible_real
        errors.add(:cantidad,
          "supera el stock disponible (#{stock.cantidad_disponible_real.round(2)} #{stock.unidad || 'g'} disponibles)")
      end
    end
  end

  # --- Flujo multi-stock: líneas construidas explícitamente (items_attributes) ---

  # Líneas nuevas (en memoria) que trae la dispensa al crearse por el flujo multi-stock.
  def lineas_nuevas
    items.select(&:new_record?)
  end

  # ¿La dispensa se está creando con líneas explícitas (multi-stock) en vez del single legacy?
  def lineas_explicitas?
    new_record? && lineas_nuevas.any?
  end

  # Espeja en las columnas legacy (stock_id/cantidad/precio) la realidad de las líneas:
  # stock primario = primera línea; cantidad = suma de las líneas. Mantiene compatibles a los
  # lectores que todavía leen dispensacion.stock/.cantidad mientras dura la transición.
  def sincronizar_mirror_desde_items
    ls = lineas_nuevas
    self.stock_id  ||= ls.first&.stock_id
    self.cantidad    = ls.sum { |l| l.cantidad.to_d }
  end

  # Valida cada línea contra el estado actual: stock existente, de la organización, y con disponible
  # suficiente (agrupando por stock para sumar líneas que repiten el mismo inventario).
  def lineas_validas
    lineas_nuevas.group_by(&:stock_id).each do |_sid, ls|
      st = ls.first.stock
      if st.nil?
        errors.add(:base, 'Una línea no tiene un stock válido.')
        next
      end
      unless st.club_id == paciente&.club_id || st.sede&.club_id == paciente&.club_id
        errors.add(:base, 'Una línea usa stock de otro club.')
        next
      end
      unless st.apto_dispensa?
        errors.add(:base, "El stock \"#{st.numero_lote_producto || st.forma_producto}\" no está habilitado para dispensa.")
        next
      end
      pedido = ls.sum { |l| l.cantidad.to_d }
      # Las líneas marcadas "desde el evento" pueden usar, además del disponible libre, lo que
      # ese evento tiene APARTADO de este stock (el apartado bloquea al resto, no al evento).
      eventos = ls.map(&:evento_bar_id).compact.uniq
      disp    = st.cantidad_disponible_real.to_d + eventos.sum { |ev| st.apartado_en_evento(ev) }
      if pedido > disp
        nombre = st.forma_producto.to_s.humanize
        errors.add(:base, "Stock insuficiente (#{nombre}): hay #{disp.round(2)}#{st.unidad || 'g'} y se piden #{pedido.to_f}#{st.unidad || 'g'}.")
      end
    end
  end

  def limite_mensual_no_superado
    return unless paciente && cantidad.to_d > 0
    limite = paciente.limite_dispensacion_mensual_g.to_d
    return if limite <= 0
    ya_dispensado = paciente.dispensado_mes_actual_g.to_d
    restante = limite - ya_dispensado
    if cantidad.to_d > restante
      errors.add(:cantidad,
        "supera el límite mensual del paciente (#{[restante, 0].max.round(1)} g disponibles de #{limite.round(1)} g/mes)")
    end
  end

  def credito_suficiente
    return unless paciente_id
    if aporte_socio_ars.to_d <= 0
      errors.add(:aporte_socio_ars, 'debe ser mayor a $0 cuando el medio de pago es cuenta corriente')
      return
    end
    cc = paciente.cuenta_corriente
    return unless cc
    # Ya no se bloquea cuando excede el crédito: el crédito cubre lo que puede
    # (monto_credito_ars) y la diferencia se cobra ahora. La validación de tener
    # crédito CONFIGURADO vive en el controller.
  end

  def credito_no_abona
    return unless paciente_id
    cc    = paciente.cuenta_corriente
    monto = aporte_socio_ars.to_d

    if cc.nil? || cc.limite_credito.to_d <= 0
      errors.add(:base, 'El paciente no tiene crédito configurado. Consultá con el administrador.')
    elsif monto <= 0
      errors.add(:base, 'No se puede determinar el valor del producto. Configurá el precio del stock.')
    elsif (cc.saldo_disponible + cc.limite_credito) < monto
      errors.add(:base, 'Crédito insuficiente para realizar la dispensa.')
    end
  end

  def gramos_suficientes
    return unless paciente_id
    cc = paciente.cuenta_corriente

    unless cc&.credito_gramos_activo?
      errors.add(:base, 'El paciente no tiene crédito en gramos activo')
      return
    end

    saldo = cc.saldo_disponible_g.to_d
    if saldo <= 0
      errors.add(:base, 'Sin saldo de gramos disponible')
    elsif cantidad.to_d > saldo
      errors.add(:cantidad, "supera el saldo en gramos disponible (#{saldo.to_f}g)")
    end
  end

  # Descuenta el stock de CADA línea (multi-stock). Cada dispensa tiene al menos su línea espejo
  # (ver asegurar_item_espejo), así que el flujo single-stock legacy descuenta vía esa única línea.
  def decrementar_stock
    items.reload.each do |it|
      next unless it.stock
      ActiveRecord::Base.transaction do
        it.stock.decrement!(:cantidad, it.cantidad)
        it.stock.stock_movimientos.create!(
          tipo:           'dispensacion',
          gramos:         -it.cantidad,
          usuario:        user,
          dispensacion_id: id,
          notas:          [
            "Dispensación ##{id} — #{paciente&.nombre_completo}",
            it.evento_bar && "desde lo apartado para «#{it.evento_bar.nombre}»",
          ].compact.join(' · '),
        )
        imputar_a_apartado_evento(it)
        # Si con esta línea se fue el último gramo, el stock queda agotado — y ese es el
        # disparador de que el lote cierre su ciclo. `decrement!` solo baja la cantidad: sin
        # esta llamada el stock quedaba 'asignado' en cero y el lote nunca pasaba a
        # 'finalizado', que es lo que ensuciaba los informes de trazabilidad.
        it.stock.reload.marcar_agotado_si_vacio!(usuario: user)
      end
    end
  end

  # Si la línea salió de lo apartado para un evento, se imputa a esa provisión: el bloqueo se
  # libera en la misma medida en que acá se descontó el stock real. Sin esto habría doble
  # descuento (baja `cantidad` Y sigue apartado), y el disponible caería el doble.
  def imputar_a_apartado_evento(item)
    return unless item.evento_bar_id && item.stock

    prov = EventoBarProvision.find_by(evento_bar_id: item.evento_bar_id,
                                      provisionable_type: 'Stock', provisionable_id: item.stock_id)
    prov&.imputar_dispensa!(item.cantidad)
  end

  # Revierte el stock de cada línea. Se llama en after_destroy: para entonces las líneas ya
  # están soft-borradas por la cascada (dependent: :destroy), así que se leen con with_deleted.
  def incrementar_stock
    items.with_deleted.each do |it|
      next unless it.stock
      ActiveRecord::Base.transaction do
        it.stock.increment!(:cantidad, it.cantidad)
        # Borra el movimiento por FK exacta; fallback por texto para registros viejos.
        movs     = it.stock.stock_movimientos.where(tipo: 'dispensacion')
        borrados = movs.where(dispensacion_id: id).destroy_all
        movs.where("notas LIKE ?", "Dispensación ##{id} —%").destroy_all if borrados.empty?
      end
    end
  end

  def generar_codigo_paquete
    self.codigo_paquete = "PKG-#{Time.zone.today.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
    self.estado_envio   = 'pendiente'
  end

  # Puente multi-stock: garantiza que toda dispensa tenga al menos una línea espejo de su
  # contenido (stock + cantidad + precio + trazabilidad). Las dispensas creadas por el flujo
  # legacy de un solo stock quedan así representadas también como líneas, que pasan a ser la
  # fuente canónica. Si la dispensa ya trae líneas propias (flujo multi-stock), no hace nada.
  def asegurar_item_espejo
    return if items.exists?
    return if cantidad.to_f <= 0
    items.create!(
      stock_id:            stock_id,
      cantidad:            cantidad,
      precio_unitario_ars: precio_unitario_ars,
      lote_codigo:         lote_codigo,
      genetica_nombre:     genetica_nombre,
    )
  end

  # Snapshot inmutable de trazabilidad: copia código de lote y genética del stock al
  # crear. Sobrevive aunque el stock se elimine después (dependent: :nullify).
  def capturar_snapshot_trazabilidad
    self.lote_codigo     ||= stock&.lote&.codigo || stock&.lote_codigo
    self.genetica_nombre ||= (stock&.genetica || stock&.lote&.genetica)&.nombre
  end

  # Token público (no adivinable) para la URL /d/:token del pasaporte.
  def generar_token
    return if token.present?
    self.token = loop do
      t = SecureRandom.urlsafe_base64(12)
      break t unless self.class.exists?(token: t)
    end
  end

  # Foto inmutable del producto al dispensar: datos que muestra la etiqueta/pasaporte.
  # Se lee de acá (no en vivo) para que sobreviva a ediciones de genética o borrado de stock.
  # Para multi-stock guarda además `items[]` con una foto por línea, para que el pasaporte
  # liste todos los productos del paquete (no solo el stock espejo de la primera línea).
  def capturar_snapshot_producto
    return if producto_snapshot.present? && producto_snapshot != {}
    snap = {
      forma_producto: stock&.forma_producto,
      cantidad:       cantidad&.to_f,
      unidad:         stock&.unidad,
      lote_codigo:    lote_codigo || stock&.lote&.codigo,
      fecha:          (fecha_dispensacion || Date.current).to_s,
      genetica:       snapshot_genetica(stock),
    }.compact

    # `items` (en memoria, antes de persistirse) trae las líneas del flujo multi-stock.
    lineas = items.to_a
    if lineas.size > 1
      snap[:items] = lineas.map do |it|
        {
          forma_producto: it.stock&.forma_producto,
          cantidad:       it.cantidad&.to_f,
          unidad:         it.stock&.unidad,
          lote_codigo:    it.lote_codigo || it.stock&.lote&.codigo,
          genetica:       snapshot_genetica(it.stock),
        }.compact
      end
    end

    self.producto_snapshot = snap
  end

  # Foto de la genética de un stock para el snapshot (nil si el stock no tiene).
  def snapshot_genetica(st)
    g = st&.genetica || st&.lote&.genetica
    return nil unless g
    {
      nombre:    g.nombre,
      tipo:      g.tipo,
      thc_pct:   g.thc&.to_f,
      cbd_pct:   g.cbd&.to_f,
      terpenos:  g.terpenos,
      registrada_inase:      g.registrada_inase,
      numero_registro_inase: g.numero_registro_inase,
    }
  end

  # Compone direccion_envio (texto para mostrar) a partir de los campos estructurados.
  def componer_direccion_envio
    return if envio_calle.blank?
    linea1    = [envio_calle, envio_altura].reject(&:blank?).join(' ')
    pisodepto = [("Piso #{envio_piso}" if envio_piso.present?),
                 ("Depto #{envio_depto}" if envio_depto.present?)].compact.join(' ')
    partes = [linea1, pisodepto.presence, envio_barrio.presence, envio_ciudad.presence].compact
    self.direccion_envio = partes.join(', ') if partes.any?
  end

  def delivery_fields_presentes
    errors.add(:direccion_envio, 'es requerida para envíos') if direccion_envio.blank?
    errors.add(:contacto_nombre, 'es requerido para envíos') if contacto_nombre.blank?
    # delivery_id se asigna después por el admin — no se valida en creación
  end

  def encolar_reporte_ariccame
    return unless paciente&.club&.feature?(:ariccame)
    ReportarAriccameJob.perform_later(id)
  end

  def dispatch_webhook
    club = paciente&.club
    return unless club

    WebhookDispatcher.dispatch(club, 'dispensacion.creada', {
      id:                id,
      fecha_dispensacion: fecha_dispensacion,
      cantidad_g:         cantidad,
      medio_pago:         medio_pago,
      paciente: {
        id:     paciente.id,
        nombre: paciente.nombre_completo,
        dni:    paciente.dni,
      },
    })
  end

  def broadcast_stock_actualizado
    return unless stock_id
    club_id = paciente&.club_id || stock&.club_id
    return unless club_id

    s = stock
    ActionCable.server.broadcast("stocks_club_#{club_id}", {
      tipo:      'stock_actualizado',
      stock_id:  stock_id,
      cantidad:  s.cantidad.to_f,
      gramos_reservados: s.gramos_reservados,
      cantidad_disponible_real: s.cantidad_disponible_real,
    })
  rescue => e
    Rails.logger.warn "Dispensacion#broadcast_stock_actualizado falló: #{e.message}"
  end

  def notificar_delivery
    return unless saved_change_to_estado_envio?
    return unless estado_envio.in?(%w[entregado fallido])

    club = paciente&.club
    return unless club

    nombre    = paciente&.nombre_completo || 'Socio'
    tipo      = estado_envio == 'entregado' ? 'delivery_entregado' : 'delivery_fallido'
    severidad = estado_envio == 'entregado' ? 'info' : 'warning'
    mensaje   = if estado_envio == 'entregado'
      "Entrega confirmada: #{nombre}"
    else
      motivo = motivo_fallo.presence || 'sin motivo especificado'
      "Fallo de entrega: #{nombre} — #{motivo}"
    end

    AlertaInterna.create!(
      club:             club,
      tipo:             tipo,
      mensaje:          mensaje,
      severidad:        severidad,
      destinada_a_role: 'supervisor',
      contexto:         { dispensacion_id: id, paciente_id: paciente_id }
    )
  rescue StandardError => e
    Rails.logger.warn "Dispensacion#notificar_delivery falló: #{e.message}"
  end

end
