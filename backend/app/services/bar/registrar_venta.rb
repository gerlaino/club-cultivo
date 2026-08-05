module Bar
  # Registra una venta de un bar de forma atómica: valida stock, arma la venta + líneas,
  # descuenta el stock de cada ítem EN SU DEPÓSITO y genera el ingreso contable (sede del bar +
  # unidad "Bar").
  #
  #   Bar::RegistrarVenta.new(bar, vendedor, lineas: [...], medio_pago: 'efectivo').call
  #   # lineas: [{ vendible_type:, vendible_id:, cantidad:, precio_unitario_ars? }, ...]
  #   # compat: [{ bar_producto_id:, cantidad: }, ...] sigue funcionando
  #
  # El mostrador vende de CUALQUIER depósito (producto del bar, insumo, stock externo) — la
  # mercadería no se duplica, cada línea descuenta de donde realmente está. Lo único que no se
  # vende acá es el stock regulatorio (flor/derivados): sale por dispensación.
  #
  # Devuelve la BarVenta persistida. Lanza ArgumentError si el stock no alcanza, falta precio,
  # el ítem no es vendible o no hay líneas.
  class RegistrarVenta
    def initialize(bar, vendedor, lineas:, medio_pago: 'efectivo', turno: nil, notas: nil,
                   evento_bar: nil, permite_precio_manual: false)
      @bar        = bar
      @club       = bar.club
      @vendedor   = vendedor
      @lineas     = Array(lineas)
      @medio_pago = medio_pago.presence || 'efectivo'
      @turno      = turno
      @notas      = notas
      @evento     = evento_bar # si se atribuye a un evento, la venta consume lo reservado
      @precio_manual = permite_precio_manual
    end

    def call
      raise ArgumentError, 'La venta no tiene productos' if @lineas.empty?
      if @evento && !@evento.permite_ventas?
        raise ArgumentError, "El evento está #{@evento.estado}: no se pueden registrar ventas."
      end

      ActiveRecord::Base.transaction do
        venta = crear_cabecera
        total = 0.to_d

        @lineas.each do |ln|
          # Línea SUELTA: se vende algo que no está en el inventario (el admin todavía no lo
          # cargó). Registra la venta y su ingreso, pero no toca stock ni pretende ser
          # inventario — no hay de qué descontar. Es la alternativa a que el mostrador frene
          # la venta o, peor, la haga por fuera del sistema y no quede registro.
          if linea_suelta?(ln)
            total += registrar_linea_suelta(venta, ln)
            next
          end

          item = resolver(ln)
          cant = ln[:cantidad].to_d
          raise ArgumentError, "Cantidad inválida para #{item.nombre}" if cant <= 0
          raise ArgumentError, item.motivo_no_vendible unless item.vendible?

          precio = precio_de(item, ln)

          # Si la venta es de un evento y el ítem tiene stock RESERVADO para ese evento, esa
          # parte ya salió del depósito al reservar → se imputa como consumida en la provisión y
          # NO vuelve a bajar stock (evita el doble descuento). El resto sale del stock normal.
          desde_reserva = consumir_de_reserva(item, cant)
          desde_stock   = cant - desde_reserva
          raise ArgumentError, "Sin stock suficiente de #{item.nombre}" if desde_stock > item.disponible

          subtotal = (precio * cant).round(2)
          venta.items.create!(
            club: @club, vendible: item.objeto,
            bar_producto: (item.objeto if item.objeto.is_a?(BarProducto)), # compat tickets viejos
            nombre: item.nombre,
            cantidad: cant, cantidad_desde_reserva: desde_reserva,
            precio_unitario_ars: precio, subtotal_ars: subtotal
          )

          if desde_stock.positive?
            item.descontar!(cantidad: desde_stock, usuario: @vendedor, venta: venta,
                            motivo: "Venta bar ##{venta.id}")
          end
          total += subtotal
        end

        venta.update!(total_ars: total)
        venta.crear_ingreso!
        venta
      end
    end

    private

    def crear_cabecera
      attrs = { club: @club, user: @vendedor, unidad_negocio: @bar.unidad_negocio_bar,
                total_ars: 0, medio_pago: @medio_pago, turno: @turno, notas: @notas, evento_bar: @evento }
      # Engancha la venta a la caja abierta. Tolerante: solo si la columna existe (feature
      # nueva); si no se migró todavía, la venta se registra igual sin caja.
      attrs[:caja_turno] = @bar.caja_abierta if BarVenta.column_names.include?('caja_turno_id')
      @bar.bar_ventas.create!(attrs)
    end

    # Sin vendible y con nombre propio: es una venta suelta. El shape viejo del POS mandaba
    # `bar_producto_id` sin `vendible_type`, así que exigimos el nombre para no confundirlos.
    def linea_suelta?(ln)
      ln[:vendible_type].blank? && ln[:bar_producto_id].blank? && ln[:nombre].present?
    end

    def registrar_linea_suelta(venta, ln)
      nombre = ln[:nombre].to_s.strip
      cant   = ln[:cantidad].to_d
      precio = ln[:precio_unitario_ars].to_d

      raise ArgumentError, 'La venta suelta necesita un nombre' if nombre.blank?
      raise ArgumentError, "Cantidad inválida para #{nombre}"   if cant <= 0
      raise ArgumentError, "Poné el precio de #{nombre}"        if precio <= 0

      subtotal = (precio * cant).round(2)
      # Sin `vendible`: el modelo ya lo admite (es opcional) y así queda claro en el ticket y
      # en los informes que esta línea no salió del inventario.
      venta.items.create!(
        club: @club, nombre: nombre, cantidad: cant,
        precio_unitario_ars: precio, subtotal_ars: subtotal
      )
      subtotal
    end

    # Compat: una línea sin vendible_type es un producto del bar (shape viejo del POS).
    def resolver(ln)
      tipo = ln[:vendible_type].presence || (ln[:bar_producto_id].present? ? 'BarProducto' : nil)
      id   = ln[:vendible_id].presence   || ln[:bar_producto_id]
      item = tipo && ItemVendible.resolver(bar: @bar, tipo: tipo, id: id)
      raise ActiveRecord::RecordNotFound, 'Producto inexistente en la venta' if item.nil?

      item
    end

    # Precio: el propio del ítem, o el manual de la línea. Un insumo no tiene precio de venta,
    # así que venderlo exige precio manual — y eso solo lo puede hacer la gestión.
    def precio_de(item, ln)
      manual = ln[:precio_unitario_ars].presence
      if manual.present?
        raise ArgumentError, 'No podés fijar el precio a mano' unless @precio_manual

        return manual.to_d
      end

      propio = item.precio_sugerido
      raise ArgumentError, "#{item.nombre} no tiene precio de venta cargado" if propio.nil? || propio <= 0

      propio.to_d
    end

    # Imputa hasta `cant` a lo reservado del ítem para el evento (si hay). Sube
    # cantidad_consumida de la provisión y devuelve cuánto se cubrió desde la reserva.
    def consumir_de_reserva(item, cant)
      return 0.to_d unless @evento

      prov = @evento.provisiones.find_by(provisionable_type: item.tipo, provisionable_id: item.id)
      return 0.to_d unless prov
      # El apartado regulatorio no se vende (ni llega acá) y su reserva no descontó stock:
      # nunca se imputa contra una venta.
      return 0.to_d if prov.apartado?

      disponible = [prov.cantidad_reservada.to_d - prov.cantidad_consumida.to_d, 0].max
      usar = [cant, disponible].min
      prov.update!(cantidad_consumida: prov.cantidad_consumida.to_d + usar) if usar.positive?
      usar
    end
  end
end
