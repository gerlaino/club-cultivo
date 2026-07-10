# Un evento de un bar (fiesta, cata, taller): un proyecto con P&L propio. El resultado real se
# arma desde el libro contable (movimientos etiquetados con evento_bar_id). Los costos/proveedores
# y las ventas de barra atribuidas al evento son las fuentes. Recuperable desde la papelera.
class EventoBar < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  self.table_name = 'eventos_bar'

  belongs_to :club
  belongs_to :bar, class_name: 'Barra'
  has_many :costos,        class_name: 'EventoBarCosto', foreign_key: :evento_bar_id, dependent: :destroy
  has_many :tareas,        class_name: 'EventoBarTarea', foreign_key: :evento_bar_id, dependent: :destroy
  has_many :tipos_entrada, class_name: 'EventoBarTipoEntrada', foreign_key: :evento_bar_id, dependent: :destroy
  has_many :entradas,      class_name: 'EventoBarEntrada', foreign_key: :evento_bar_id, dependent: :destroy
  has_many :provisiones,   class_name: 'EventoBarProvision', foreign_key: :evento_bar_id, dependent: :destroy
  # class_name explícito: 'movimientos_contables'.classify → 'MovimientosContable' (mal, el
  # inflector deja "movimientos" en plural). El modelo real es MovimientoContable.
  has_many :movimientos_contables, class_name: 'MovimientoContable', foreign_key: :evento_bar_id, dependent: :nullify
  has_many :bar_ventas,            class_name: 'BarVenta',           foreign_key: :evento_bar_id, dependent: :nullify

  ESTADOS = %w[planificado en_venta en_curso finalizado cancelado].freeze

  validates :nombre, presence: true
  validates :estado, inclusion: { in: ESTADOS }
  validates :presupuesto_ingresos, numericality: { greater_than_or_equal_to: 0 }

  scope :proximos, -> { where('fecha >= ? OR fecha IS NULL', Date.current).order(Arel.sql('fecha IS NULL, fecha ASC')) }
  scope :pasados,  -> { where('fecha < ?', Date.current).order(fecha: :desc) }

  # P&L real: ingresos − egresos del libro etiquetados con este evento.
  def resultado
    ingresos = movimientos_contables.where(tipo: %w[ingreso recupero_costo]).sum(:monto_ars)
    egresos  = movimientos_contables.where(tipo: 'egreso').sum(:monto_ars)
    { ingresos: ingresos.to_f, egresos: egresos.to_f, resultado: (ingresos - egresos).to_f }
  end

  # Presupuesto: ingresos estimados y egresos comprometidos (suma de costos, pagados o no).
  def costos_comprometidos = costos.sum(:monto_ars).to_f
  def costos_pagados       = costos.where(pagado: true).sum(:monto_ars).to_f

  # Resultado proyectado: lo estimado de ingresos menos lo comprometido en costos.
  def resultado_proyectado
    (presupuesto_ingresos.to_d - costos.sum(:monto_ars).to_d).to_f
  end

  # ── Entradas ──────────────────────────────────────────────
  def entradas_vendidas   = entradas.vigentes.count
  def recaudacion_entradas = entradas.vigentes.sum(:precio_ars).to_f

  # Precio promedio de los tipos activos (para estimar el break-even en cantidad de entradas).
  def precio_entrada_promedio
    precios = tipos_entrada.activos.where('precio_ars > 0').pluck(:precio_ars)
    return 0.0 if precios.empty?

    (precios.sum / precios.size).to_f
  end

  # Cuántas entradas hay que vender para cubrir los costos comprometidos.
  def break_even_entradas
    prom = precio_entrada_promedio
    return nil if prom <= 0

    (costos.sum(:monto_ars).to_d / prom).ceil
  end
end
