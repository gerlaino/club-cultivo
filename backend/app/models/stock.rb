class Stock < ApplicationRecord
  include Restorable
  belongs_to :sede,     optional: true
  belongs_to :lote,     optional: true
  belongs_to :pesada,   optional: true
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :genetica, optional: true
  belongs_to :producido_desde_stock, class_name: 'Stock', optional: true

  has_many :stock_movimientos, dependent: :destroy
  has_many :dispensaciones, class_name: 'Dispensacion', dependent: :nullify
  has_many :reservas, dependent: :nullify
  has_many :derivados, class_name: 'Stock', foreign_key: :producido_desde_stock_id, dependent: :nullify

  ORIGENES         = %w[lote derivado_lote compra_externa].freeze
  FORMAS_PRODUCTO  = %w[flor_seca hash aceite tintura crema capsula comestible prensado preroll prearmado otro externo].freeze
  UNIDADES         = %w[g ml un].freeze
  CATEGORIAS_EXTERNA = %w[merch bebida insumo otros].freeze
  ESTADOS          = %w[pendiente_asignacion asignado agotado].freeze

  validates :origen,        inclusion: { in: ORIGENES }
  validates :forma_producto, inclusion: { in: FORMAS_PRODUCTO }
  validates :unidad,        inclusion: { in: UNIDADES }
  validates :cantidad,      numericality: { greater_than_or_equal_to: 0 }
  validates :estado,        inclusion: { in: ESTADOS }
  validates :costo_unitario_ars,  numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :precio_sugerido_ars, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  attr_accessor :es_split

  validate :validar_segun_origen

  before_validation :set_club_id, on: :create
  before_create :set_cantidad_inicial
  before_create :generar_numero_lote_producto
  before_create :generar_codigo_qr
  before_create :descontar_lote_origen_si_corresponde, unless: -> { es_split }
  # Cuando el stock de un lote se agota, el lote pasa a 'finalizado' (si era el último).
  after_save :finalizar_lote_si_agotado, if: -> { saved_change_to_estado? && estado == 'agotado' && lote_id.present? }

  scope :regulatorios,             -> { where(origen: %w[lote derivado_lote]) }
  scope :sociales,                 -> { where(origen: 'compra_externa') }
  scope :disponibles,              -> { where('cantidad > 0') }
  scope :pendientes_asignacion,    -> { where(estado: 'pendiente_asignacion') }
  scope :asignados,                -> { where(estado: 'asignado') }
  scope :del_club,                 -> { where(sede_id: nil) }

  def pendiente_asignacion? = estado == 'pendiente_asignacion'
  def asignado?             = estado == 'asignado'
  def agotado?              = estado == 'agotado'
  def del_club?             = sede_id.nil?

  # Stock comprometido pero todavía no descontado: envíos de dispensaciones en curso
  # MÁS reservas pendientes de entrega. Al entregar una reserva se crea la Dispensacion
  # (que descuenta el real) y la reserva pasa a 'entregada', dejando de contar acá — sin
  # doble conteo.
  def gramos_reservados
    envios   = dispensaciones.where(estado_envio: %w[pendiente en_viaje]).sum(:cantidad).to_f
    apartado = reservas.pendientes.sum(:cantidad).to_f
    envios + apartado
  end

  def cantidad_disponible_real
    # OJO: los envíos pendientes/en viaje YA se descontaron de `cantidad` al crearse la
    # dispensación (after_create :decrementar_stock). NO se vuelven a restar acá (eso era un
    # doble descuento que dejaba el disponible en ~0 tras una entrega grande). Solo restamos las
    # reservas (apartado), que comprometen stock SIN descontar el real.
    [cantidad.to_f - reservas.pendientes.sum(:cantidad).to_f, 0].max
  end

  def dias_para_vencimiento
    return nil unless fecha_vencimiento_est
    (fecha_vencimiento_est - Date.today).to_i
  end

  def estado_vencimiento
    return nil unless fecha_vencimiento_est
    dias = dias_para_vencimiento
    if    dias < 0  then 'vencido'
    elsif dias <= 7 then 'critico'
    elsif dias <= 30 then 'proximo'
    else 'ok'
    end
  end

  def asignar!(sede:, usuario:, notas: nil)
    ActiveRecord::Base.transaction do
      update!(sede: sede, estado: 'asignado')
      stock_movimientos.create!(
        tipo:             'transferencia',
        gramos:           cantidad,
        sede_origen_id:   nil,
        sede_destino_id:  sede.id,
        usuario:          usuario,
        notas:            notas,
      )
    end
  end

  delegate :nombre,  to: :lote, prefix: :lote, allow_nil: true
  delegate :codigo,  to: :lote, prefix: :lote, allow_nil: true

  def regulatorio?
    origen.in?(%w[lote derivado_lote])
  end

  private

  def set_club_id
    self.club_id ||= sede&.club_id || lote&.club_id
  end

  # "Cantidad inicial" = lo que entró originalmente. Para stock externo/derivado nace con
  # su cantidad; el de manicura nace en 0 y se acumula vía produccion en PesajeManicura#confirmar!.
  def set_cantidad_inicial
    self.cantidad_inicial ||= cantidad
  end

  public

  # ── VERDAD ÚNICA de las cantidades de un stock ─────────────────────────────────
  # cantidad_inicial = lo que se INGRESÓ al crear el stock (externo: lo cargado; de lote: la
  #                    suma del pesaje de cada planta). Es editable: si se corrige, ese número
  #                    pasa a ser el inicial. Es el "Total". Las operaciones NO lo tocan.
  # cantidad         = lo que hay AHORA, ya descontadas dispensaciones, producción y traslados.
  #                    Es el "Actual". Lo mutan las operaciones.
  def disponible = cantidad_disponible_real.to_d # lo que queda libre (actual − reservado)

  def generar_numero_lote_producto
    return if numero_lote_producto.present?
    return unless club_id
    year = Date.today.strftime("%y")
    loop do
      result = ActiveRecord::Base.connection.execute(
        "UPDATE clubs SET lote_numero_seq = COALESCE(lote_numero_seq, 0) + 1 WHERE id = #{club_id.to_i} RETURNING lote_numero_seq"
      )
      seq = result.first['lote_numero_seq']
      candidate = "ST-#{year}-#{seq.to_s.rjust(4, '0')}"
      unless Stock.where(club_id: club_id).exists?(numero_lote_producto: candidate)
        self.numero_lote_producto = candidate
        break
      end
    end
  end

  def generar_codigo_qr
    return if codigo_qr.present?
    cid = club_id || sede&.club_id || lote&.club_id
    return unless cid
    self.codigo_qr = "S-#{cid}-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end

  def validar_segun_origen
    case origen
    when 'lote'
      errors.add(:lote_id, 'es obligatorio para origen lote')        if lote_id.blank?
      # cualquier forma_producto válida al cerrar curado
    when 'derivado_lote'
      return if es_split
      errors.add(:lote_id, 'es obligatorio para derivados')           if lote_id.blank?
      errors.add(:lote_origen_consumido_g, 'debe ser mayor a 0')     if lote_origen_consumido_g.to_d <= 0
      errors.add(:forma_producto, 'no puede ser flor_seca para derivados') if forma_producto == 'flor_seca'
      if cantidad.to_d > lote_origen_consumido_g.to_d
        errors.add(:cantidad, "no puede superar los gramos consumidos (#{lote_origen_consumido_g}g consumidos → #{cantidad}g resultado)")
      end
    when 'compra_externa'
      errors.add(:proveedor, 'es obligatorio para compra externa') if proveedor.blank?
      errors.add(:lote_id,   'debe ser nulo para compra externa')  if lote_id.present?
    end
  end

  def finalizar_lote_si_agotado
    lote&.finalizar_si_stock_agotado!
  end

  def descontar_lote_origen_si_corresponde
    return unless origen == 'derivado_lote' && lote_id.present? && lote_origen_consumido_g.to_d > 0

    stock_flor = Stock.find_by(lote_id: lote_id, forma_producto: 'flor_seca', origen: 'lote')
    unless stock_flor
      errors.add(:base, "No existe stock de flor seca para el lote #{lote_id}")
      throw :abort
    end
    if stock_flor.cantidad < lote_origen_consumido_g
      errors.add(:lote_origen_consumido_g,
        "excede el stock disponible de flor seca del lote (#{stock_flor.cantidad}g disponibles)")
      throw :abort
    end

    stock_flor.decrement!(:cantidad, lote_origen_consumido_g)
  end
end
