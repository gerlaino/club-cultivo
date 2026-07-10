module Bar
  # Registra una venta de un bar de forma atómica: valida stock, arma la venta + líneas,
  # descuenta el stock de cada producto y genera el ingreso contable (sede del bar + unidad "Bar").
  #
  #   Bar::RegistrarVenta.new(bar, vendedor, lineas: [...], medio_pago: 'efectivo').call
  #   # lineas: [{ bar_producto_id:, cantidad: }, ...]
  #
  # Devuelve la BarVenta persistida. Lanza ArgumentError si el stock no alcanza o no hay líneas.
  class RegistrarVenta
    def initialize(bar, vendedor, lineas:, medio_pago: 'efectivo', turno: nil, notas: nil)
      @bar        = bar
      @club       = bar.club
      @vendedor   = vendedor
      @lineas     = Array(lineas)
      @medio_pago = medio_pago.presence || 'efectivo'
      @turno      = turno
      @notas      = notas
    end

    def call
      raise ArgumentError, 'La venta no tiene productos' if @lineas.empty?

      ActiveRecord::Base.transaction do
        attrs = { club: @club, user: @vendedor, unidad_negocio: @bar.unidad_negocio_bar,
                  total_ars: 0, medio_pago: @medio_pago, turno: @turno, notas: @notas }
        # Engancha la venta a la caja abierta. Tolerante: solo si la columna existe (feature
        # nueva); si no se migró todavía, la venta se registra igual sin caja.
        attrs[:caja_turno] = @bar.caja_abierta if BarVenta.column_names.include?('caja_turno_id')
        venta = @bar.bar_ventas.create!(attrs)

        total = 0.to_d
        @lineas.each do |ln|
          prod = @bar.bar_productos.find(ln[:bar_producto_id])
          cant = ln[:cantidad].to_d
          raise ArgumentError, "Cantidad inválida para #{prod.nombre}" if cant <= 0
          raise ArgumentError, "Sin stock suficiente de #{prod.nombre}" if cant > prod.stock.to_d

          subtotal = (prod.precio_ars.to_d * cant).round(2)
          venta.items.create!(
            club: @club, bar_producto: prod, nombre: prod.nombre,
            cantidad: cant, precio_unitario_ars: prod.precio_ars, subtotal_ars: subtotal
          )
          # Descuenta stock dejando el movimiento en el ledger del depósito (si la tabla existe).
          if BarStockMovimiento.table_exists?
            prod.registrar_salida!(cantidad: cant, tipo: 'venta', created_by: @vendedor, bar_venta: venta)
          else
            prod.update!(stock: prod.stock.to_d - cant)
          end
          total += subtotal
        end

        venta.update!(total_ars: total)
        venta.crear_ingreso!
        venta
      end
    end
  end
end
