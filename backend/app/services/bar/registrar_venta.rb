module Bar
  # Registra una venta del bar de forma atómica: valida stock, arma la venta + líneas,
  # descuenta el stock de cada producto y genera el ingreso contable en la unidad "Bar".
  #
  #   Bar::RegistrarVenta.new(club, vendedor, lineas: [...], medio_pago: 'efectivo').call
  #   # lineas: [{ bar_producto_id:, cantidad: }, ...]
  #
  # Devuelve la BarVenta persistida. Lanza ArgumentError si el stock no alcanza o no hay líneas.
  class RegistrarVenta
    def initialize(club, vendedor, lineas:, medio_pago: 'efectivo', turno: nil, notas: nil)
      @club       = club
      @vendedor   = vendedor
      @lineas     = Array(lineas)
      @medio_pago = medio_pago.presence || 'efectivo'
      @turno      = turno
      @notas      = notas
    end

    def call
      raise ArgumentError, 'La venta no tiene productos' if @lineas.empty?

      ActiveRecord::Base.transaction do
        venta = @club.bar_ventas.create!(
          user: @vendedor, unidad_negocio: unidad_bar,
          total_ars: 0, medio_pago: @medio_pago, turno: @turno, notas: @notas
        )

        total = 0.to_d
        @lineas.each do |ln|
          prod = @club.bar_productos.find(ln[:bar_producto_id])
          cant = ln[:cantidad].to_d
          raise ArgumentError, "Cantidad inválida para #{prod.nombre}" if cant <= 0
          raise ArgumentError, "Sin stock suficiente de #{prod.nombre}" if cant > prod.stock.to_d

          subtotal = (prod.precio_ars.to_d * cant).round(2)
          venta.items.create!(
            club: @club, bar_producto: prod, nombre: prod.nombre,
            cantidad: cant, precio_unitario_ars: prod.precio_ars, subtotal_ars: subtotal
          )
          prod.update!(stock: prod.stock.to_d - cant)
          total += subtotal
        end

        venta.update!(total_ars: total)
        venta.update!(movimiento_contable: crear_ingreso(venta, total))
        venta
      end
    end

    private

    def crear_ingreso(venta, total)
      @club.movimientos_contables.create!(
        created_by: @vendedor, tipo: 'ingreso',
        categoria: 'otro', categoria_contable: categoria_venta_bar,
        unidad_negocio: unidad_bar,
        descripcion: "Venta bar ##{venta.id}",
        monto_ars: total, fecha: Date.current,
        pagado: true, medio_pago: @medio_pago,
        comprobante_tipo: 'sin_comprobante'
      )
    end

    # Unidad de negocio "Bar" del club (la crea si el catálogo no fue sembrado aún).
    def unidad_bar
      @unidad_bar ||= @club.unidades_negocio.create_with(nombre: 'Bar', es_sistema: true)
                          .find_or_create_by!(tipo: 'bar')
    end

    # Categoría "Venta bar" (ingreso). clave_sistema nil → el string legacy cae en 'otro'.
    def categoria_venta_bar
      @categoria_venta_bar ||= @club.categorias_contables.create_with(
        tipo: 'ingreso', unidad_negocio: unidad_bar, es_sistema: true
      ).find_or_create_by!(nombre: 'Venta bar')
    end
  end
end
