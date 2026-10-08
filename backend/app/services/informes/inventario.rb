module Informes
  # EL INFORME DE STOCK (Germán, 29-sep-2026): los stocks con su información, como Dispensaciones
  # pero mirando el producto. Contesta tres preguntas:
  #
  #   1. Qué hay HOY — por producto y unidad, propio y externo: cuánto queda, cuánto está sobre una
  #      mesa, cuánto está comprometido (eventos y reservas) y cuánto está libre. Y su valor.
  #   2. Qué pasó en el PERÍODO — una fila por stock: qué ingresó, qué se dispensó, merma, otras
  #      salidas y ajustes. Es donde se busca por qué un stock tiene lo que tiene.
  #   3. Lo que no se mueve y lo que vence — stock con saldo sin salida hace un mes, y vencimientos.
  #
  # Reglas que no se rompen acá:
  #   · Por unidad, nunca sumado entre unidades (gramos, unidades, ml). La plata sí se suma.
  #   · La mesa es un LUGAR, no un compromiso: «libre» es `disponible_para_entregar` (queda menos
  #     eventos y reservas), el mismo número que valida la dispensa. Si lo calculara distinto, el
  #     informe diría «hay» y el mostrador no dejaría entregar.
  #   · Lo dispensado sale de las LÍNEAS (`Informes::Dispensaciones#lineas_en`), el mismo conteo
  #     que el informe de dispensaciones: si fueran dos cuentas, algún día no coincidirían.
  #   · INGRESÓ no se cuenta dos veces. El pesaje de manicura suma a `cantidad_inicial` Y deja un
  #     movimiento `produccion`; un fraccionado nace con `cantidad_inicial` Y una transferencia
  #     positiva. Por eso: un stock que nació en el período ingresó su `cantidad_inicial`; uno de
  #     antes, lo que le entró por movimientos positivos de producción o traslado. Y en los dos
  #     casos, la mercadería que llegó después a un stock externo (`ingreso`), que no está en el
  #     inicial.
  #   · Sin merch ni bebidas (forma `externo`): es un informe de producto.
  #   · CADA FILA CIERRA (7-oct-2026, Germán: «33 − 43 + 27 no da 193,8»): Había + Ingresó −
  #     Dispensado − Merma − Otras salidas ± Ajustes = Quedaba. «Quedaba» es el saldo al FINAL del
  #     período (el de hoy, deshaciendo lo que pasó después) y «Había» sale de la cuenta. Un stock
  #     que nació en el período había 0: si con eso no cierra, la fila lo dice (`descuadre`) en vez
  #     de esconderlo en «Había».
  class Inventario
    DIAS_SIN_MOVIMIENTO = 30
    DIAS_VENCE_PRONTO   = 30
    # Salidas que no son dispensa ni merma, cada una con su nombre en la fila.
    OTRAS_SALIDAS = %w[transferencia produccion consumo_evento consumo salida].freeze

    def initialize(club:, desde:, hasta:, filtros: nil)
      @club    = club
      @desde   = desde
      @hasta   = hasta
      @filtros = filtros || Filtros.new(club: club)
      @hoy     = Time.zone.today
    end

    def call
      stocks = stocks_del_informe
      filas  = stocks.map { |s| fila(s) }
      {
        hoy:            hoy(filas),
        stocks:         filas,
        periodo:        periodo(filas),
        ingresos:       ingresos_por_genetica(filas),
        sin_movimiento: sin_movimiento(filas),
        vencen:         vencen(filas),
        filtros:        @filtros.to_h,
      }
    end

    # ── Qué stocks entran ──────────────────────────────────────────────────────

    # Los de la organización (filtrados) que tienen saldo hoy o que tuvieron algo en el período
    # (nacieron, se movieron o se dispensaron). Un agotado de hace un año no entra: no pasó nada.
    def stocks_del_informe
      base = ::Stock.where(club_id: @club.id).where.not(forma_producto: 'externo')
      base = base.where.not(origen: 'compra_externa') unless @filtros.externo?
      base = base.where(origen: 'compra_externa')     unless @filtros.propio?
      base = base.where(lote_id: @filtros.lote_ids)   if @filtros.lote_ids
      base = base.where(sede_id: @filtros.sede_ids)   if @filtros.sede_ids
      base = base.where(forma_producto: @filtros.formas) if @filtros.formas
      if @filtros.genetica_ids
        base = base.left_joins(:lote).where('stocks.genetica_id IN (:ids) OR (stocks.genetica_id IS NULL AND lotes.genetica_id IN (:ids))',
                                            ids: @filtros.genetica_ids)
      end

      activos = movimientos_periodo.keys + dispensado_periodo.keys
      rel = base.where('stocks.cantidad > 0')
                .or(base.where(created_at: rango_tiempo))
                .or(base.where(id: activos.uniq))
      rel = rel.where('stocks.cantidad > 0') if @filtros.saldo == 'con_saldo'
      rel = rel.where('stocks.cantidad <= 0') if @filtros.saldo == 'agotados'

      lista = rel.includes(:sede, :genetica, lote: :genetica).to_a
      ::Stock.precargar_apartados(lista)
      lista.sort_by { |s| [s.forma_producto.to_s, s.numero_lote_producto.to_s] }
    end

    def rango_tiempo = @desde.beginning_of_day..@hasta.end_of_day

    # ── Una fila por stock ─────────────────────────────────────────────────────

    def fila(s)
      movs      = movimientos_periodo[s.id] || []
      nacio_aca = rango_tiempo.cover?(s.created_at)
      ingreso   = if nacio_aca
                    s.cantidad_inicial.to_d
                  else
                    movs.select { |m| %w[produccion transferencia].include?(m.tipo) && m.gramos.positive? }.sum(&:gramos).to_d
                  end
      # La mercadería que llegó a un stock externo ya existente NO está en el inicial: se suma
      # siempre, haya nacido el stock en el período o antes.
      ingreso  += movs.select { |m| m.tipo == 'ingreso' }.sum(&:gramos).to_d
      dispensado = dispensado_periodo[s.id].to_d
      merma      = movs.select { |m| m.tipo == 'merma' }.sum { |m| -m.gramos.to_d }
      # Neto: una devolución (positiva) de un evento resta de las salidas. Lo positivo de producción
      # y traslado ya está en «Ingresó» (o en el inicial de uno nacido acá): no se cuenta dos veces.
      otras      = movs.select { |m| OTRAS_SALIDAS.include?(m.tipo) && !(%w[produccion transferencia].include?(m.tipo) && m.gramos.positive?) }
                       .sum { |m| -m.gramos.to_d }
      ajustes    = movs.select { |m| m.tipo == 'ajuste' }.sum { |m| m.gramos.to_d }
      queda        = s.cantidad.to_d
      # Al final del período: lo de hoy, deshaciendo lo que pasó después (movimientos fechados
      # después y dispensas con fecha posterior, contadas por línea como «Dispensado»).
      quedaba    = queda - movimientos_despues[s.id].to_d + dispensado_despues[s.id].to_d
      neto       = ingreso - dispensado - merma - otras + ajustes
      habia      = nacio_aca ? 0.to_d : quedaba - neto
      descuadre  = nacio_aca ? (quedaba - neto) : [habia, 0].min
      comprometido = s.apartado_para_eventos.to_d + s.apartado_para_reservas.to_d
      costo  = s.costo_unitario_ars
      precio = s.precio_sugerido_ars
      {
        id:           s.id,
        numero:       s.numero_lote_producto,
        producto:     s.forma_producto,
        unidad:       s.unidad,
        genetica:     s.genetica&.nombre || s.lote&.genetica&.nombre || s.descripcion,
        origen:       s.origen == 'compra_externa' ? 'externo' : 'propio',
        de_donde:     s.origen == 'compra_externa' ? s.proveedor : s.lote&.codigo,
        sede:         s.sede&.nombre,
        alta:         s.created_at.to_date,
        ingreso:      ingreso.round(2).to_f,
        habia:        habia.round(2).to_f,
        dispensado:   dispensado.round(2).to_f,
        merma:        merma.round(2).to_f,
        otras_salidas: otras.round(2).to_f,
        ajustes:      ajustes.round(2).to_f,
        quedaba:      quedaba.round(2).to_f,
        # Lo que no cierra (≠ 0 sólo si los movimientos no explican el saldo): se muestra.
        descuadre:    descuadre.abs >= 0.01 ? descuadre.round(2).to_f : nil,
        # Los ajustes uno por uno, para ver quién, cuándo y por qué.
        ajustes_detalle: movs.select { |m| m.tipo == 'ajuste' }.map { |m|
          { fecha: m.fecha || m.created_at.to_date, gramos: m.gramos.to_f, notas: m.notas.presence,
            quien: m.usuario && [m.usuario.first_name, m.usuario.last_name].compact.join(' ').presence || m.usuario&.email }
        },
        queda:        queda.round(2).to_f,
        en_mesa:      [s.apartado_para_mostrador.to_d, queda].min.round(2).to_f,
        comprometido: [comprometido, queda].min.round(2).to_f,
        libre:        s.disponible_para_entregar.round(2).to_f,
        vence:        s.fecha_vencimiento_est,
        ultima_salida: ultima_salida[s.id],
        valor_costo:  costo  ? (queda * costo).round(2).to_f  : nil,
        valor_venta:  precio ? (queda * precio).round(2).to_f : nil,
      }
    end

    # Los movimientos del período que no son dispensa (la dispensa se cuenta por línea), por stock.
    def movimientos_periodo
      @movimientos_periodo ||= StockMovimiento.joins(:stock).where(stocks: { club_id: @club.id })
                                              .en_periodo(@desde, @hasta)
                                              .where.not(tipo: 'dispensacion')
                                              .includes(:usuario)
                                              .to_a.group_by(&:stock_id)
    end

    # Lo que pasó DESPUÉS del período, para volver del saldo de hoy al del final: el neto de los
    # movimientos (sin dispensas) y lo dispensado por línea.
    def movimientos_despues
      @movimientos_despues ||= StockMovimiento.joins(:stock).where(stocks: { club_id: @club.id })
                                              .where.not(tipo: 'dispensacion')
                                              .where('COALESCE(stock_movimientos.fecha, stock_movimientos.created_at::date) > ?', @hasta.to_date)
                                              .group(:stock_id).sum(:gramos)
    end

    def dispensado_despues
      return {} if @hasta.to_date >= @hoy

      @dispensado_despues ||= Dispensaciones.new(club: @club, desde: @hasta + 1, hasta: @hoy)
                                            .lineas_en(@hasta.to_date + 1, @hoy)
                                            .select(&:stock)
                                            .group_by { |l| l.stock.id }
                                            .transform_values { |ls| ls.sum(&:cantidad) }
    end

    # Lo dispensado en el período por stock, desde las líneas — respetando los filtros de la
    # dispensa (paciente, sede, quién) que el informe de stock no usa, así que son «todos».
    def dispensado_periodo
      @dispensado_periodo ||= Dispensaciones.new(club: @club, desde: @desde, hasta: @hasta)
                                            .lineas_en(@desde, @hasta)
                                            .select(&:stock)
                                            .group_by { |l| l.stock.id }
                                            .transform_values { |ls| ls.sum(&:cantidad) }
    end

    # La última vez que salió algo de cada stock, en toda su vida. Las dispensas por SU fecha (la
    # de la dispensa), no por el movimiento que dejaron: ese se fecha el día que se cargó, y una
    # dispensa anotada hoy con fecha de hace 40 días hacía parecer que el stock salió hoy.
    def ultima_salida
      @ultima_salida ||= begin
        del_club = ::Stock.where(club_id: @club.id).select(:id)
        items  = DispensacionItem.joins(:dispensacion).merge(Dispensacion.no_canceladas)
                                 .where(stock_id: del_club)
                                 .group(:stock_id).maximum('dispensaciones.fecha_dispensacion')
        # Las dispensas de antes del carrito no tienen líneas: su stock es `stock_id`.
        viejas = Dispensacion.no_canceladas.where(stock_id: del_club).where.missing(:items)
                             .group(:stock_id).maximum(:fecha_dispensacion)
        movs   = StockMovimiento.where(stock_id: del_club).where('gramos < 0').where.not(tipo: 'dispensacion')
                                .group(:stock_id).maximum(Arel.sql('COALESCE(stock_movimientos.fecha, stock_movimientos.created_at::date)'))
        [items, viejas, movs].reduce { |a, b| a.merge(b) { |_, x, y| [x, y].compact.max } }
      end
    end

    # ── 1. Hoy ─────────────────────────────────────────────────────────────────

    # Por unidad y origen: queda, en mesa, comprometido, libre. Y la plata, que sí se suma.
    def hoy(filas)
      con_saldo = filas.select { |f| f[:queda].positive? }
      {
        por_unidad: con_saldo.group_by { |f| [f[:unidad], f[:origen]] }.sort.map { |(u, o), fs|
          { unidad: u, origen: o, stocks: fs.size,
            queda: suma(fs, :queda), en_mesa: suma(fs, :en_mesa),
            comprometido: suma(fs, :comprometido), libre: suma(fs, :libre) }
        },
        stocks_con_saldo: con_saldo.size,
        valor_costo:  con_saldo.sum { |f| f[:valor_costo].to_f }.round(2),
        valor_venta:  con_saldo.sum { |f| f[:valor_venta].to_f }.round(2),
        sin_costo:    con_saldo.count { |f| f[:valor_costo].nil? },
        sin_precio:   con_saldo.count { |f| f[:valor_venta].nil? },
      }
    end

    # ── 2. El período, sumado por unidad ───────────────────────────────────────

    def periodo(filas)
      filas.group_by { |f| f[:unidad] }.sort.map do |u, fs|
        { unidad: u, habia: suma(fs, :habia), ingreso: suma(fs, :ingreso), dispensado: suma(fs, :dispensado),
          merma: suma(fs, :merma), otras_salidas: suma(fs, :otras_salidas), ajustes: suma(fs, :ajustes),
          quedaba: suma(fs, :quedaba) }
      end
    end

    # Lo que entró en el período, por genética: es como se presenta («en septiembre entraron
    # 500 g de Gorilla y 200 de Amnesia»). Por producto y unidad, nunca sumado entre unidades.
    def ingresos_por_genetica(filas)
      filas.select { |f| f[:ingreso].positive? }
           .group_by { |f| [f[:genetica], f[:producto], f[:unidad], f[:origen]] }
           .map { |(g, prod, u, o), fs| { genetica: g, producto: prod, unidad: u, origen: o, stocks: fs.size, ingreso: suma(fs, :ingreso) } }
           .sort_by { |r| [r[:origen], r[:genetica].to_s, r[:producto].to_s] }
    end

    # ── 3. Lo que no se mueve y lo que vence ───────────────────────────────────

    # Con saldo y sin ninguna salida hace más de un mes (o nunca). Días desde la última salida, o
    # desde el alta si nunca salió nada.
    def sin_movimiento(filas)
      filas.filter_map do |f|
        next unless f[:queda].positive?

        desde = f[:ultima_salida] || f[:alta]
        dias  = (@hoy - desde.to_date).to_i
        next if dias < DIAS_SIN_MOVIMIENTO

        f.merge(dias_quieto: dias, nunca_salio: f[:ultima_salida].nil?)
      end.sort_by { |f| -f[:dias_quieto] }
    end

    def vencen(filas)
      filas.filter_map do |f|
        next unless f[:queda].positive? && f[:vence]

        dias = (f[:vence] - @hoy).to_i
        next if dias > DIAS_VENCE_PRONTO

        f.merge(dias_para_vencer: dias)
      end.sort_by { |f| f[:dias_para_vencer] }
    end

    def suma(fs, k) = fs.sum { |f| f[k].to_d }.round(2).to_f
  end
end
