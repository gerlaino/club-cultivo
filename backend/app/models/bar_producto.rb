# Producto del bar = ítem del depósito del salón (deposito_bar). Se compra (costo promedio
# ponderado), se vende (POS), se provisiona/consume en eventos, y cada cambio de stock deja un
# movimiento auditable. `costo_ars` es el costo unitario (para margen y valorizado).
class BarProducto < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :bar, class_name: 'Barra'
  belongs_to :unidad_negocio, optional: true
  has_many :bar_venta_items,       dependent: :nullify
  has_many :bar_stock_movimientos, dependent: :destroy

  CATEGORIAS = %w[bebida cocina merch otro].freeze

  validates :nombre, presence: true
  validates :categoria, inclusion: { in: CATEGORIAS }
  validates :precio_ars, :stock, :stock_minimo, numericality: { greater_than_or_equal_to: 0 }

  scope :activos,    -> { where(activo: true) }
  scope :stock_bajo, -> { where('stock_minimo > 0 AND stock <= stock_minimo') }

  def stock_bajo?
    stock_minimo.to_d.positive? && stock.to_d <= stock_minimo.to_d
  end

  def margen_pct
    return nil if costo_ars.blank? || precio_ars.to_d.zero?

    (((precio_ars.to_d - costo_ars.to_d) / precio_ars.to_d) * 100).round(1)
  end

  def valorizado_ars = (stock.to_d * costo_ars.to_d).round(2)

  # Compra: suma stock, recalcula el costo promedio ponderado y (opcional) genera el egreso en el
  # libro etiquetado con la sede del bar + unidad "Bar". Deja un movimiento 'compra'.
  def registrar_compra!(cantidad:, costo_total_ars:, created_by:, proveedor: nil, generar_egreso: true)
    cantidad    = cantidad.to_d
    costo_total = costo_total_ars.to_d
    raise ArgumentError, 'La cantidad debe ser mayor a 0' if cantidad <= 0
    raise ArgumentError, 'El costo debe ser mayor a 0'    if costo_total <= 0

    transaction do
      ant   = stock.to_d
      nuevo = ant + cantidad
      self.costo_ars = ((ant * costo_ars.to_d) + costo_total) / nuevo # promedio ponderado móvil
      self.stock     = nuevo
      save!

      mov = registrar_movimiento!(tipo: 'compra', cantidad: cantidad, stock_anterior: ant,
                                  created_by: created_by, costo_unitario_ars: (costo_total / cantidad).round(4),
                                  motivo: proveedor.present? ? "Compra a #{proveedor}" : 'Compra')
      if generar_egreso
        egr = club.movimientos_contables.create!(
          sede_id: bar.sede_id, created_by: created_by, tipo: 'egreso',
          categoria: 'otro', unidad_negocio: bar.unidad_negocio_bar,
          descripcion: "Compra mercadería salón — #{nombre} (#{cantidad.to_s('F')})",
          monto_ars: costo_total, fecha: Date.current, pagado: true, medio_pago: 'efectivo'
        )
        mov.update!(movimiento_contable: egr)
      end
      mov
    end
  end

  # Salida de stock (venta / reserva de evento / merma). Descuenta y deja movimiento.
  def registrar_salida!(cantidad:, tipo:, created_by:, bar_venta: nil, evento_bar: nil, motivo: nil)
    cantidad = cantidad.to_d
    raise ArgumentError, 'Cantidad inválida'               if cantidad <= 0
    raise ArgumentError, "Sin stock suficiente de #{nombre}" if cantidad > stock.to_d

    ant = stock.to_d
    update!(stock: ant - cantidad)
    mov = registrar_movimiento!(tipo: tipo, cantidad: cantidad, stock_anterior: ant, created_by: created_by,
                                bar_venta: bar_venta, evento_bar: evento_bar, motivo: motivo)
    avisar_reposicion!
    mov
  end

  # Entrada de stock (devolución de sobrante de evento). Suma y deja movimiento.
  def registrar_ingreso!(cantidad:, tipo:, created_by:, evento_bar: nil, motivo: nil)
    cantidad = cantidad.to_d
    return if cantidad <= 0

    ant = stock.to_d
    update!(stock: ant + cantidad)
    registrar_movimiento!(tipo: tipo, cantidad: cantidad, stock_anterior: ant, created_by: created_by,
                          evento_bar: evento_bar, motivo: motivo)
  end

  # Ajuste manual del stock (conteo/merma). Fija el stock al valor contado y registra la diferencia.
  def ajustar_stock!(cantidad_nueva:, created_by:, motivo: nil)
    nueva = cantidad_nueva.to_d
    raise ArgumentError, 'El stock no puede ser negativo' if nueva.negative?

    ant  = stock.to_d
    diff = nueva - ant
    return if diff.zero?

    update!(stock: nueva)
    registrar_movimiento!(tipo: diff.negative? ? 'merma' : 'ajuste', cantidad: diff.abs,
                          stock_anterior: ant, created_by: created_by,
                          motivo: motivo.presence || 'Ajuste de stock')
  end

  # Aviso de reposición cuando el stock llega al mínimo (best-effort, anti-spam 12h).
  def avisar_reposicion!
    return unless stock_bajo?
    return if AlertaInterna.where(club_id: club_id, tipo: 'stock_bajo')
                           .where("contexto ->> 'bar_producto_id' = ?", id.to_s)
                           .where('created_at > ?', 12.hours.ago).exists?

    club.alertas_internas.create!(
      tipo: 'stock_bajo', severidad: 'warning', destinada_a_role: 'admin',
      mensaje: "Reponer #{nombre} (salón): quedan #{stock.to_f.round(2)} (mínimo #{stock_minimo.to_f.round(2)}).",
      contexto: { 'bar_producto_id' => id, 'origen' => 'bar' }
    )
  rescue StandardError => e
    Rails.logger.error "[BarProducto] aviso de reposición: #{e.message}"
  end

  private

  def registrar_movimiento!(tipo:, cantidad:, stock_anterior:, created_by:, costo_unitario_ars: nil,
                            motivo: nil, bar_venta: nil, evento_bar: nil)
    bar_stock_movimientos.create!(
      club: club, created_by: created_by, tipo: tipo, cantidad: cantidad,
      stock_anterior: stock_anterior, stock_nuevo: stock, costo_unitario_ars: costo_unitario_ars,
      motivo: motivo, bar_venta: bar_venta, evento_bar: evento_bar
    )
  end
end
