module Bar
  # Registra una venta de un bar de forma atómica: valida stock, arma la venta + líneas,
  # descuenta el stock de cada producto y genera el ingreso contable (sede del bar + unidad "Bar").
  #
  #   Bar::RegistrarVenta.new(bar, vendedor, lineas: [...], medio_pago: 'efectivo').call
  #   # lineas: [{ bar_producto_id:, cantidad: }, ...]
  #
  # Devuelve la BarVenta persistida. Lanza ArgumentError si el stock no alcanza o no hay líneas.
  class RegistrarVenta
    def initialize(bar, vendedor, lineas:, medio_pago: 'efectivo', turno: nil, notas: nil, evento_bar: nil)
      @bar        = bar
      @club       = bar.club
      @vendedor   = vendedor
      @lineas     = Array(lineas)
      @medio_pago = medio_pago.presence || 'efectivo'
      @turno      = turno
      @notas      = notas
      @evento     = evento_bar # si se atribuye a un evento, la venta consume lo reservado
    end

    def call
      raise ArgumentError, 'La venta no tiene productos' if @lineas.empty?
      if @evento && !@evento.permite_ventas?
        raise ArgumentError, "El evento está #{@evento.estado}: no se pueden registrar ventas."
      end

      ActiveRecord::Base.transaction do
        attrs = { club: @club, user: @vendedor, unidad_negocio: @bar.unidad_negocio_bar,
                  total_ars: 0, medio_pago: @medio_pago, turno: @turno, notas: @notas, evento_bar: @evento }
        # Engancha la venta a la caja abierta. Tolerante: solo si la columna existe (feature
        # nueva); si no se migró todavía, la venta se registra igual sin caja.
        attrs[:caja_turno] = @bar.caja_abierta if BarVenta.column_names.include?('caja_turno_id')
        venta = @bar.bar_ventas.create!(attrs)

        total = 0.to_d
        @lineas.each do |ln|
          prod = @bar.bar_productos.find(ln[:bar_producto_id])
          cant = ln[:cantidad].to_d
          raise ArgumentError, "Cantidad inválida para #{prod.nombre}" if cant <= 0

          # Si la venta es de un evento y el producto tiene stock RESERVADO para ese evento,
          # esa parte ya salió del depósito al reservar → se imputa como consumida en la
          # provisión y NO vuelve a bajar stock (evita el doble descuento). El resto sale
          # del stock normal.
          desde_reserva = consumir_de_reserva(prod, cant)
          desde_stock   = cant - desde_reserva
          raise ArgumentError, "Sin stock suficiente de #{prod.nombre}" if desde_stock > prod.stock.to_d

          subtotal = (prod.precio_ars.to_d * cant).round(2)
          venta.items.create!(
            club: @club, bar_producto: prod, nombre: prod.nombre,
            cantidad: cant, precio_unitario_ars: prod.precio_ars, subtotal_ars: subtotal
          )

          if desde_stock.positive?
            if BarStockMovimiento.table_exists?
              prod.registrar_salida!(cantidad: desde_stock, tipo: 'venta', created_by: @vendedor, bar_venta: venta)
            else
              prod.update!(stock: prod.stock.to_d - desde_stock)
            end
          end
          total += subtotal
        end

        venta.update!(total_ars: total)
        venta.crear_ingreso!
        venta
      end
    end

    private

    # Imputa hasta `cant` a lo reservado del producto para el evento (si hay). Sube
    # cantidad_consumida de la provisión y devuelve cuánto se cubrió desde la reserva.
    def consumir_de_reserva(prod, cant)
      return 0.to_d unless @evento

      prov = @evento.provisiones.find_by(provisionable_type: 'BarProducto', provisionable_id: prod.id)
      return 0.to_d unless prov

      disponible = [prov.cantidad_reservada.to_d - prov.cantidad_consumida.to_d, 0].max
      usar = [cant, disponible].min
      prov.update!(cantidad_consumida: prov.cantidad_consumida.to_d + usar) if usar.positive?
      usar
    end
  end
end
