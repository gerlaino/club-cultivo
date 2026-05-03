class Stock < ApplicationRecord
  belongs_to :sede, optional: true
  belongs_to :lote, optional: true

  has_many :dispensaciones,    dependent: :nullify
  has_many :stock_movimientos, dependent: :destroy

  ORIGENES         = %w[lote derivado_lote compra_externa].freeze
  FORMAS_PRODUCTO  = %w[flor_seca hash aceite tintura crema capsula comestible prensado otro externo].freeze
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

  validate :validar_segun_origen

  before_create :descontar_lote_origen_si_corresponde

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

  def validar_segun_origen
    case origen
    when 'lote'
      errors.add(:lote_id, 'es obligatorio para origen lote')        if lote_id.blank?
      # cualquier forma_producto válida al cerrar curado
    when 'derivado_lote'
      errors.add(:lote_id, 'es obligatorio para derivados')           if lote_id.blank?
      errors.add(:lote_origen_consumido_g, 'debe ser mayor a 0')     if lote_origen_consumido_g.to_d <= 0
      errors.add(:forma_producto, 'no puede ser flor_seca para derivados') if forma_producto == 'flor_seca'
    when 'compra_externa'
      errors.add(:proveedor,   'es obligatorio para compra externa')  if proveedor.blank?
      errors.add(:descripcion, 'es obligatoria para compra externa')  if descripcion.blank?
      errors.add(:lote_id,     'debe ser nulo para compra externa')   if lote_id.present?
    end
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
