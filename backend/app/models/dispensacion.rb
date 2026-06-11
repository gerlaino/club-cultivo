class Dispensacion < ApplicationRecord
  self.table_name = 'dispensaciones'

  ESTADOS_ENVIO = %w[pendiente en_viaje entregado fallido].freeze
  MEDIOS_PAGO   = %w[efectivo transferencia cuenta_corriente no_abona].freeze

  belongs_to :paciente
  belongs_to :user
  belongs_to :indicacion_medica, optional: true
  belongs_to :stock
  belongs_to :sede,          optional: true
  belongs_to :delivery_user, class_name: 'User', foreign_key: :delivery_id, optional: true

  has_one :movimiento_contable, dependent: :nullify

  before_validation { self.fecha_dispensacion ||= Date.current }
  before_create     :generar_codigo_paquete, if: :con_envio?

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
  validate  :delivery_fields_presentes, if: :con_envio?

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
    margen = cc.saldo_disponible + cc.limite_credito
    if margen < aporte_socio_ars.to_d
      errors.add(:base, 'No se puede realizar la dispensa. Sin crédito disponible. Consultá con el administrador.')
    end
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

  def decrementar_stock
    return unless stock
    ActiveRecord::Base.transaction do
      stock.decrement!(:cantidad, cantidad)
      stock.stock_movimientos.create!(
        tipo:    'dispensacion',
        gramos:  -cantidad,
        usuario: user,
        notas:   "Dispensación ##{id} — #{paciente&.nombre_completo}",
      )
    end
  end

  def incrementar_stock
    stock&.increment!(:cantidad, cantidad)
  end

  def generar_codigo_paquete
    self.codigo_paquete = "PKG-#{Date.today.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
    self.estado_envio   = 'pendiente'
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
