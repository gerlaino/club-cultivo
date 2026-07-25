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
  # El "carril" del evento por fases (el stepper de la UI). cancelado vive fuera del carril.
  CARRIL = %w[planificado en_venta en_curso finalizado].freeze
  # Un evento finalizado o cancelado no acepta más ventas (entradas ni barra) y es TERMINAL:
  # no se reabre (una vez que se devolvió el sobrante y se asentó el P&L, es un hecho consumado).
  ESTADOS_SIN_VENTA = %w[finalizado cancelado].freeze
  def permite_ventas? = ESTADOS_SIN_VENTA.exclude?(estado)
  def terminal? = ESTADOS_SIN_VENTA.include?(estado)

  # Estados a los que se puede pasar desde `desde`: cualquier punto del carril (avanzar o corregir
  # hacia atrás) + cancelar. Desde un estado terminal no se puede salir.
  def self.transiciones_desde(desde)
    return [] if ESTADOS_SIN_VENTA.include?(desde)

    (CARRIL - [desde] + ['cancelado']).uniq
  end
  def transiciones_validas = self.class.transiciones_desde(estado)

  validates :nombre, presence: true
  validates :estado, inclusion: { in: ESTADOS }
  validates :presupuesto_ingresos, numericality: { greater_than_or_equal_to: 0 }
  validate  :transicion_valida, on: :update

  scope :proximos, -> { where('fecha >= ? OR fecha IS NULL', Date.current).order(Arel.sql('fecha IS NULL, fecha ASC')) }
  scope :pasados,  -> { where('fecha < ?', Date.current).order(fecha: :desc) }

  # P&L real del evento: ingresos − costos directos (DJ/sonido) − COSTO DE LA MERCADERÍA
  # consumida (COGS). El COGS no es un asiento nuevo (la mercadería ya se gastó al comprarla al
  # depósito): es la atribución al evento de lo que costó lo que se vendió/consumió. Sin él, el
  # resultado exagera la ganancia.
  def resultado
    ingresos = movimientos_contables.where(tipo: %w[ingreso recupero_costo]).sum(:monto_ars).to_d
    egresos  = movimientos_contables.where(tipo: 'egreso').sum(:monto_ars).to_d
    cogs     = costo_mercaderia.to_d
    {
      ingresos:  ingresos.to_f,
      egresos:   egresos.to_f,
      cogs:      cogs.to_f,
      resultado: (ingresos - egresos - cogs).to_f,
    }
  end

  # Costo de la mercadería consumida en el evento (Σ cantidad_consumida × costo unitario).
  def costo_mercaderia
    provisiones.includes(:provisionable).sum { |p| p.cantidad_consumida.to_d * p.costo_unitario }
  end

  # Devuelve al depósito todo el sobrante reservado (reservado − consumido) de cada provisión.
  # Idempotente: al hacerlo deja el sobrante en 0, así correrlo de nuevo no devuelve de más.
  # Se llama al finalizar/cancelar por cualquier camino (así no queda stock atrapado fuera).
  def devolver_sobrante_reservado!(usuario:)
    transaction do
      provisiones.includes(:provisionable).each do |p|
        sobrante = p.sobrante
        next if sobrante <= 0

        p.aplicar_devolucion!(cantidad: sobrante, usuario: usuario)
        p.update!(cantidad_reservada: p.cantidad_consumida) # sobrante → 0
      end
    end
  end

  # Presupuesto: ingresos estimados y egresos comprometidos (suma de costos, pagados o no).
  def costos_comprometidos = costos.sum(:monto_ars).to_f
  def costos_pagados       = costos.where(pagado: true).sum(:monto_ars).to_f

  # Resultado proyectado: ingresos estimados menos costos comprometidos. La proyección es
  # honesta — toma el MAYOR entre el presupuesto cargado a mano y lo YA recaudado (entradas +
  # ventas de barra del libro), para no ignorar lo vendido cuando supera la estimación.
  def resultado_proyectado
    ingreso_estimado = [presupuesto_ingresos.to_d, resultado[:ingresos].to_d].max
    (ingreso_estimado - costos.sum(:monto_ars).to_d).to_f
  end

  # ── Entradas / aforo ──────────────────────────────────────
  def entradas_vendidas   = entradas.vigentes.count
  def recaudacion_entradas = entradas.vigentes.sum(:precio_ars).to_f

  # Lugares que quedan según el aforo (nil = sin aforo definido = sin límite).
  def aforo_disponible
    return nil if aforo.to_i <= 0
    [aforo.to_i - entradas_vendidas, 0].max
  end
  def aforo_completo? = aforo.to_i.positive? && entradas_vendidas >= aforo.to_i

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

  private

  # Bloquea reabrir un evento terminal (y cualquier transición no contemplada). No aplica en
  # :create ni cuando el estado no cambia. `estado_was` nil (registros viejos) → no valida.
  def transicion_valida
    return unless estado_changed? && estado_was.present?
    return if self.class.transiciones_desde(estado_was).include?(estado)

    errors.add(:estado, "no se puede pasar de #{estado_was} a #{estado}")
  end
end
