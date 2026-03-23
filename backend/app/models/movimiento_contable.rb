# backend/app/models/movimiento_contable.rb
class MovimientoContable < ApplicationRecord
  self.table_name = "movimientos_contables"

  belongs_to :club
  belongs_to :sede,         optional: true
  belongs_to :lote,         optional: true
  belongs_to :dispensacion, optional: true
  belongs_to :created_by,   class_name: "User"

  TIPOS = %w[egreso ingreso recupero_costo ajuste].freeze

  CATEGORIAS = %w[
    insumo electricidad agua alquiler sueldo mantenimiento
    honorario seguro admin aporte_socio dispensacion subvencion otro
  ].freeze

  CATEGORIA_LABELS = {
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
    "otro"          => "Otro",
  }.freeze

  TIPOS_COMPROBANTE = %w[factura_a factura_b recibo ticket sin_comprobante].freeze
  MEDIOS_PAGO       = %w[efectivo transferencia mercado_pago cheque].freeze

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
  validate  :fecha_no_futura

  scope :egresos,          -> { where(tipo: %w[egreso]) }
  scope :ingresos,         -> { where(tipo: %w[ingreso recupero_costo]) }
  scope :del_periodo,      ->(desde, hasta) { where(fecha: desde..hasta) }
  scope :del_mes,          ->(fecha = Date.today) {
    where(fecha: fecha.beginning_of_month..fecha.end_of_month)
  }
  scope :por_sede,         ->(sede_id) { where(sede_id: sede_id) }
  scope :por_lote,         ->(lote_id) { where(lote_id: lote_id) }
  scope :recientes,        -> { order(fecha: :desc, created_at: :desc) }

  def categoria_label
    CATEGORIA_LABELS[categoria] || categoria
  end

  def tipo_label
    { "egreso" => "Egreso", "ingreso" => "Ingreso",
      "recupero_costo" => "Recupero de costo", "ajuste" => "Ajuste" }[tipo] || tipo
  end

  def es_egreso?
    tipo == "egreso"
  end

  def es_ingreso?
    %w[ingreso recupero_costo].include?(tipo)
  end

  private

  def fecha_no_futura
    errors.add(:fecha, "no puede ser futura") if fecha.present? && fecha > Date.today
  end
end