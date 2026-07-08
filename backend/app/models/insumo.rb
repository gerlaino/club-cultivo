# Insumo de cultivo en depósito (fertilizante, sustrato, macetas…). Se compra a granel y
# se consume a lo largo del tiempo imputando el costo al lote/sala donde se usó.
# Costeo: promedio ponderado móvil — `costo_promedio_ars` se recalcula en cada compra.
class Insumo < ApplicationRecord
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :categoria_contable, optional: true
  has_many :insumo_compras,  dependent: :destroy
  has_many :insumo_consumos, dependent: :destroy

  UNIDADES = %w[unidad litro mililitro kilogramo gramo bolsa metro otro].freeze

  validates :nombre, presence: true
  validates :unidad_medida, inclusion: { in: UNIDADES }
  validates :stock_actual, :costo_promedio_ars, :stock_minimo,
            numericality: { greater_than_or_equal_to: 0 }

  scope :activos,    -> { where(activo: true) }
  scope :stock_bajo, -> { where('stock_minimo > 0 AND stock_actual <= stock_minimo') }

  def valorizado_ars
    (stock_actual.to_d * costo_promedio_ars.to_d).round(2)
  end

  def stock_bajo?
    stock_minimo.to_d.positive? && stock_actual.to_d <= stock_minimo.to_d
  end

  # Compra: suma stock y recalcula el costo promedio ponderado móvil. Opcionalmente genera
  # el egreso en el libro contable (la plata sale al comprar). Devuelve la InsumoCompra.
  def registrar_compra!(cantidad:, costo_total_ars:, created_by:, proveedor: nil,
                        fecha: Date.current, sede: nil, generar_egreso: true)
    cantidad    = cantidad.to_d
    costo_total = costo_total_ars.to_d
    raise ArgumentError, 'La cantidad debe ser mayor a 0' if cantidad <= 0
    raise ArgumentError, 'El costo debe ser mayor a 0'    if costo_total <= 0

    transaction do
      nuevo_stock = stock_actual.to_d + cantidad
      # Promedio ponderado móvil: (valor_previo + valor_compra) / stock_total
      self.costo_promedio_ars = ((stock_actual.to_d * costo_promedio_ars.to_d) + costo_total) / nuevo_stock
      self.stock_actual = nuevo_stock
      save!

      compra = insumo_compras.create!(
        club: club, created_by: created_by,
        cantidad: cantidad, costo_total_ars: costo_total,
        costo_unitario_ars: (costo_total / cantidad).round(4),
        proveedor: proveedor, fecha: fecha
      )

      if generar_egreso
        mov = club.movimientos_contables.create!(
          sede: sede, created_by: created_by, tipo: 'egreso',
          categoria: 'insumo', categoria_contable: categoria_contable,
          unidad_negocio_id: categoria_contable&.unidad_negocio_id,
          descripcion: "Compra insumo — #{nombre} (#{cantidad.to_s('F')} #{unidad_medida})",
          monto_ars: costo_total, fecha: fecha, proveedor: proveedor,
          pagado: true, medio_pago: 'efectivo'
        )
        compra.update!(movimiento_contable: mov)
      end

      compra
    end
  end

  # Consumo: descuenta stock e imputa el costo (al promedio actual) al lote/sala. Refleja el
  # costo en el CostoLote. Devuelve la InsumoConsumo. Lanza si no hay stock suficiente.
  def registrar_consumo!(cantidad:, created_by:, lote: nil, sala: nil,
                         fecha: Date.current, notas: nil)
    cantidad = cantidad.to_d
    raise ArgumentError, 'La cantidad debe ser mayor a 0' if cantidad <= 0
    raise ArgumentError, 'Stock insuficiente'             if cantidad > stock_actual.to_d

    transaction do
      costo_imputado   = (cantidad * costo_promedio_ars.to_d).round(2)
      self.stock_actual = stock_actual.to_d - cantidad
      save!

      consumo = insumo_consumos.create!(
        club: club, created_by: created_by,
        cantidad: cantidad, costo_imputado_ars: costo_imputado,
        lote: lote, sala: sala, fecha: fecha, notas: notas
      )

      # El costo del lote se recalcula para reflejar el consumo imputado.
      CostoDesdeLibroService.new(lote: lote, actualizado_por: created_by).call if lote

      consumo
    end
  end
end
