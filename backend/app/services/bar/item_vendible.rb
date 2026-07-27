module Bar
  # Envoltorio ÚNICO de "algo que se puede vender o proveer en el salón", sin importar en qué
  # depósito viva: BarProducto (Salón), Insumo (Cultivo/General) o Stock externo (merch/bebida).
  #
  # Existe para que el POS, la provisión de eventos y la reversión de una venta hablen un solo
  # idioma (nombre / precio / costo / disponible / descontar! / reponer!) en vez de repetir el
  # `case` por tipo en cada lugar.
  #
  # REGLA DURA: NINGÚN `Stock` se vende por el salón — ni el propio, ni los derivados, ni el
  # externo (merch/bebida). Todo lo que es Stock sale del inventario por dispensación, que es lo
  # que deja la trazabilidad; una segunda puerta de salida por el mostrador duplicaría el canal
  # para el mismo ítem. Se puede APARTAR para un evento (ver EventoBarProvision), nunca cobrar
  # por el POS. El mostrador vende productos del bar e insumos.
  class ItemVendible
    TIPOS = %w[BarProducto Insumo Stock].freeze

    attr_reader :objeto

    def initialize(objeto)
      @objeto = objeto
    end

    # Resuelve un vendible del club validando pertenencia. Devuelve nil si no existe o el tipo
    # no es válido (el que llama decide el error).
    def self.resolver(bar:, tipo:, id:)
      club = bar.club
      obj = case tipo.to_s
            when 'BarProducto' then bar.bar_productos.find_by(id: id)
            when 'Insumo'      then club.insumos.activos.find_by(id: id)
            when 'Stock'       then Stock.where(club_id: club.id).find_by(id: id)
            end
      obj && new(obj)
    end

    def tipo = objeto.class.name
    def id   = objeto.id

    def nombre
      objeto.is_a?(Stock) ? objeto.etiqueta : objeto.nombre
    end

    def unidad
      case objeto
      when Stock then objeto.unidad.presence || 'g'
      else objeto.respond_to?(:unidad_medida) ? objeto.unidad_medida : 'u'
      end
    end

    # salon | cultivo | general | dispensacion | externo
    def deposito
      case objeto
      when BarProducto then 'salon'
      when Insumo      then objeto.tipo
      when Stock       then objeto.regulatorio? ? 'dispensacion' : 'externo'
      end
    end

    def disponible
      case objeto
      when BarProducto then objeto.stock.to_d
      when Insumo      then objeto.stock_actual.to_d
      when Stock       then objeto.cantidad_disponible_real.to_d
      end
    end

    def costo_unitario
      case objeto
      when BarProducto then objeto.costo_ars.to_d
      when Insumo      then objeto.costo_promedio_ars.to_d
      when Stock       then objeto.costo_unitario_ars.to_d
      end
    end

    # Precio de venta propio del ítem. nil = no tiene precio cargado → el POS exige uno manual
    # (y solo la gestión puede ponerlo).
    def precio_sugerido
      case objeto
      when BarProducto then objeto.precio_ars.to_d
      when Stock       then objeto.precio_sugerido_ars&.to_d # informativo: no se vende por el POS
      when Insumo      then nil # un insumo no tiene precio de venta: es materia prima
      end
    end

    # ¿Se puede cobrar por el mostrador? Ningún Stock (sale por dispensación).
    def vendible?
      return false if objeto.is_a?(Stock)
      return objeto.vendible != false if objeto.is_a?(BarProducto) && objeto.respond_to?(:vendible)

      true
    end

    def motivo_no_vendible
      return nil if vendible?
      return "#{nombre} es stock del dispensario: se entrega por dispensación, no por el mostrador." if objeto.is_a?(Stock)

      "#{nombre} está marcado como «no vender» (uso interno)."
    end

    # ── Movimientos (venta por el mostrador) ───────────────────────────────
    # Solo BarProducto e Insumo: un Stock nunca llega acá (vendible? lo frena antes). El raise
    # es una red: si alguna vez se cuela, que explote fuerte y no que descuente por la puerta
    # equivocada, sin dispensación.
    def descontar!(cantidad:, usuario:, venta: nil, motivo: nil)
      cantidad = cantidad.to_d
      raise ArgumentError, "Sin stock suficiente de #{nombre}" if cantidad > disponible

      case objeto
      when BarProducto
        objeto.registrar_salida!(cantidad: cantidad, tipo: 'venta', created_by: usuario,
                                 bar_venta: venta, motivo: motivo)
      when Insumo
        objeto.descontar_stock!(cantidad: cantidad)
      else
        raise ArgumentError, motivo_no_vendible || "#{nombre} no se puede vender por el mostrador"
      end
    end

    def reponer!(cantidad:, usuario:, motivo: nil)
      cantidad = cantidad.to_d
      return if cantidad <= 0

      case objeto
      when BarProducto then objeto.increment!(:stock, cantidad)
      when Insumo      then objeto.reponer_stock!(cantidad: cantidad)
      end
    end
  end
end
