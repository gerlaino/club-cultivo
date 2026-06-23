class Dispensacion < ApplicationRecord
  self.table_name = 'dispensaciones'

  ESTADOS_ENVIO = %w[pendiente en_viaje entregado fallido cancelada].freeze
  MEDIOS_PAGO   = %w[efectivo transferencia cuenta_corriente no_abona credito_gramos].freeze

  belongs_to :paciente
  belongs_to :user
  belongs_to :indicacion_medica, optional: true
  belongs_to :stock
  belongs_to :sede,          optional: true
  belongs_to :delivery_user, class_name: 'User', foreign_key: :delivery_id, optional: true
  belongs_to :ruta_entrega,  optional: true

  # Los asientos contables de la dispensación viven y mueren con ella. Puede haber
  # más de uno cuando se paga parte con crédito (deuda) y parte en efectivo (ingreso).
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :destroy

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
  validate  :stock_pertenece_al_club,    on: :create
  validate  :stock_disponible,           on: :create
  validate  :limite_mensual_no_superado, on: :create
  validate  :credito_suficiente,        on: :create, if: -> { medio_pago == 'cuenta_corriente' }
  validate  :credito_no_abona,          on: :create, if: -> { medio_pago == 'no_abona' }
  validate  :gramos_suficientes,        on: :create, if: -> { medio_pago == 'credito_gramos' }
  # Solo al crear: los campos de envío se exigen al generar el despacho, no en cada
  # update. Si no, marcar 'entregado'/'fallido' (que re-guarda) podía romper con 422
  # cuando un despacho viejo tenía algún campo de envío vacío.
  validate  :delivery_fields_presentes, on: :create, if: :con_envio?

  # Una dispensación cancelada conserva su registro e historia, pero NO cuenta como
  # dispensada (se revirtió stock y plata). Excluila de todo agregado de cantidad/conteo.
  # OJO: estado_envio es NULL en dispensaciones sin envío (la mayoría). where.not las
  # excluiría, así que incluimos explícitamente los NULL.
  scope :no_canceladas,  ->                     { where("dispensaciones.estado_envio IS NULL OR dispensaciones.estado_envio != 'cancelada'") }
  def cancelada? = estado_envio == 'cancelada'

  scope :del_mes,        ->(fecha = Date.today) { where(fecha_dispensacion: fecha.beginning_of_month..fecha.end_of_month) }
  scope :del_paciente,   ->(paciente_id)        { where(paciente_id: paciente_id) }
  scope :recientes,      ->                     { order(fecha_dispensacion: :desc, created_at: :desc) }
  scope :con_envio,      ->                     { where(con_envio: true) }
  scope :del_delivery,   ->(user_id)            { where(delivery_id: user_id) }
  scope :estado_envio,   ->(estado)             { where(estado_envio: estado) }
  scope :pendientes_envio, ->                   { con_envio.where(estado_envio: 'pendiente') }
  scope :en_viaje,       ->                     { con_envio.where(estado_envio: 'en_viaje') }

  after_create        :decrementar_stock
  after_create_commit :encolar_reporte_ariccame
  after_create_commit :dispatch_webhook
  after_create_commit :broadcast_stock_actualizado
  after_update_commit :broadcast_stock_actualizado, if: :estado_envio_changed?
  after_commit        :notificar_delivery, on: [:update]
  after_destroy       :incrementar_stock

  private

  def fecha_no_futura
    errors.add(:fecha_dispensacion, 'no puede ser futura') if fecha_dispensacion.present? && fecha_dispensacion > Date.today
  end

  def paciente_activo_como_socio
    return unless paciente
    errors.add(:base, 'El socio no está activo en el club') unless paciente.es_paciente?
  end

  def stock_pertenece_al_club
    return unless stock && paciente
    club_id = paciente.club_id
    unless stock.club_id == club_id || stock.sede&.club_id == club_id
      errors.add(:stock, 'no pertenece al club')
    end
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

  def decrementar_stock
    return unless stock
    ActiveRecord::Base.transaction do
      stock.decrement!(:cantidad, cantidad)
      stock.stock_movimientos.create!(
        tipo:           'dispensacion',
        gramos:         -cantidad,
        usuario:        user,
        dispensacion_id: id,
        notas:          "Dispensación ##{id} — #{paciente&.nombre_completo}",
      )
    end
  end

  def incrementar_stock
    return unless stock
    ActiveRecord::Base.transaction do
      stock.increment!(:cantidad, cantidad)
      # Borra el movimiento por FK exacta; fallback por texto para registros viejos.
      movs    = stock.stock_movimientos.where(tipo: 'dispensacion')
      borrados = movs.where(dispensacion_id: id).destroy_all
      movs.where("notas LIKE ?", "Dispensación ##{id} —%").destroy_all if borrados.empty?
    end
  end

  def generar_codigo_paquete
    self.codigo_paquete = "PKG-#{Date.today.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
    self.estado_envio   = 'pendiente'
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
  def capturar_snapshot_producto
    return if producto_snapshot.present? && producto_snapshot != {}
    g = stock&.genetica || stock&.lote&.genetica
    self.producto_snapshot = {
      forma_producto: stock&.forma_producto,
      cantidad:       cantidad&.to_f,
      unidad:         stock&.unidad,
      lote_codigo:    lote_codigo || stock&.lote&.codigo,
      fecha:          (fecha_dispensacion || Date.current).to_s,
      genetica: g && {
        nombre:    g.nombre,
        tipo:      g.tipo,
        thc_pct:   g.thc&.to_f,
        cbd_pct:   g.cbd&.to_f,
        terpenos:  g.terpenos,
        registrada_inase:      g.registrada_inase,
        numero_registro_inase: g.numero_registro_inase,
      },
    }.compact
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
