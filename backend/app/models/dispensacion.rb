class Dispensacion < ApplicationRecord
  self.table_name = 'dispensaciones'

  ESTADOS_ENVIO = %w[pendiente en_viaje entregado fallido].freeze
  MEDIOS_PAGO   = %w[efectivo transferencia cuenta_corriente credito_gramos no_abona].freeze

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
  validate  :gramos_suficientes,        on: :create, if: -> { medio_pago == 'credito_gramos' }
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
      if cantidad.to_d > stock.cantidad.to_d
        errors.add(:cantidad,
          "supera el stock disponible (#{stock.cantidad.to_f} #{stock.unidad || 'g'} disponibles)")
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
    return unless paciente_id && aporte_socio_ars.to_d > 0
    cc = paciente.cuenta_corriente
    return unless cc
    margen = cc.saldo_disponible + cc.limite_credito
    if margen < aporte_socio_ars.to_d
      errors.add(:base, 'No se puede realizar la dispensa. Sin crédito disponible. Consultá con el administrador.')
    end
  end

  def gramos_suficientes
    return unless paciente_id && cantidad.to_d > 0
    saldo = paciente.saldo_cc_g.to_d
    if saldo <= 0
      errors.add(:base, 'El paciente no tiene crédito en gramos disponible.')
    elsif cantidad.to_d > saldo
      errors.add(:cantidad, "supera el crédito en gramos disponible (#{saldo.round(2)}g disponibles)")
    end
  end

  def decrementar_stock
    stock&.decrement!(:cantidad, cantidad)
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

end
