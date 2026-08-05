module Bar
  # Pulso del bar: el dato crudo del panel inteligente del salón. No solo números — también las
  # "lecturas" (insights accionables) derivadas de datos que ya capturamos: ventas, costo de
  # mercadería (costo_ars del producto) y stock. Todo honesto, sin inventar métricas.
  class Pulso
    def initialize(bar:, hoy: Time.zone.today)
      @bar  = bar
      @club = bar.club
      @hoy  = hoy
    end

    def call
      {
        resultado_mes:   resultado_mes,
        hoy:             hoy_stats,
        caja:            caja_activa,
        ventas_por_hora: ventas_por_hora,
        top_productos:   top_productos,
        reponer:         reponer,
        sueltas_mes:     sueltas_mes,
        lecturas:        lecturas,
      }
    end

    # Caja de turno activa (abierta o pendiente de cierre, o nil) con sus totales en vivo.
    # Incluye pendiente_cierre para que el panel de gestión vea el cierre esperando confirmación.
    def caja_activa
      c = @bar.caja_activa
      return nil if c.nil?

      {
        id:                    c.id,
        estado:                c.estado,
        apertura_confirmada:   c.apertura_confirmada?,
        monto_inicial_ars:     c.monto_inicial_ars.to_f,
        total_ventas_ars:      c.total_ventas_ars,
        total_efectivo_ars:    c.total_efectivo_ars,
        total_digital_ars:     c.total_digital_ars,
        tickets:               c.tickets,
        efectivo_esperado_ars: c.efectivo_esperado_ars,
        efectivo_declarado_ars: c.efectivo_declarado_ars&.to_f,
        abierta_at:            c.abierta_at,
        abierta_por:           c.abierta_por&.nombre_completo,
        cierre_solicitado_at:  c.cierre_solicitado_at,
        cierre_solicitado_por: c.cierre_solicitado_por&.nombre_completo,
      }
    end

    private

    # ── Resultado del mes (fuente contable) + margen + comparativa con el mes pasado ──
    def resultado_mes
      actual = @bar.resultado_periodo(@hoy.beginning_of_month, @hoy)
      ini_prev = @hoy.beginning_of_month - 1.month
      prev = @bar.resultado_periodo(ini_prev, ini_prev + (@hoy.day - 1).days) # mismo tramo del mes pasado
      margen = actual[:ingresos].positive? ? ((actual[:resultado] / actual[:ingresos]) * 100).round(1) : nil
      delta  = prev[:resultado].abs.positive? ? (((actual[:resultado] - prev[:resultado]) / prev[:resultado].abs) * 100).round : nil
      actual.merge(margen_pct: margen, delta_pct: delta, resultado_prev: prev[:resultado])
    end

    # ── Ventas de hoy: caja (efectivo/digital), tickets, margen bruto del día ──
    def hoy_stats
      total    = ventas_hoy.sum(:total_ars).to_f
      pm       = ventas_hoy.group(:medio_pago).sum(:total_ars).transform_values(&:to_f)
      efectivo = pm['efectivo'].to_f
      tickets  = ventas_hoy.count
      {
        total:           total,
        tickets:         tickets,
        ticket_promedio: tickets.positive? ? (total / tickets).round(2) : 0,
        efectivo:        efectivo,
        digital:         (total - efectivo).round(2),
        por_medio_pago:  pm,
        margen_bruto_pct: margen_bruto_hoy,
      }
    end

    # Curva de ventas por hora del día (para el gráfico). En la tz del server; el volumen de un
    # día es chico, así que se agrupa en Ruby sin depender de groupdate.
    def ventas_por_hora
      buckets = Hash.new(0.0)
      ventas_hoy.pluck(:created_at, :total_ars).each do |created, total|
        buckets[created.in_time_zone.hour] += total.to_f
      end
      (0..23).map { |h| { hora: h, total: buckets[h].round(2) } }
    end

    # Top de hoy por unidades, con el margen del producto (si tiene costo cargado).
    def top_productos
      items_hoy.group(:bar_producto_id).sum(:cantidad)
               .reject { |pid, _| pid.nil? }
               .sort_by { |_pid, cant| -cant }
               .first(8)
               .map do |pid, cant|
        p = productos_by_id[pid]
        { nombre: p&.nombre || 'Producto', categoria: p&.categoria,
          cantidad: cant.to_f, margen_pct: p&.margen_pct }
      end
    end

    def reponer
      @bar.bar_productos.activos.stock_bajo.order(:nombre).map do |p|
        min = p.stock_minimo.to_f
        pct = min.positive? ? [(p.stock.to_f / min * 100).round, 100].min : 0
        { id: p.id, nombre: p.nombre, stock: p.stock.to_f, minimo: min, pct: pct }
      end
    end

    # Ventas de cosas que NO están en el catálogo (líneas sueltas del POS). Son legítimas —el
    # mostrador cobra igual y queda registrado— pero si se repiten significa que hay productos
    # sin cargar: el inventario no las ve y no tienen costo, así que no aportan margen real.
    # Se muestra para que la gestión las cargue, no para prohibirlas.
    def sueltas_mes
      items = BarVentaItem
              .joins(:bar_venta)
              .where(bar_ventas: { unidad_negocio_id: @bar.unidad_negocio_bar&.id })
              .where(bar_ventas: { created_at: Time.zone.now.all_month })
              .where(vendible_id: nil, bar_producto_id: nil)

      total = items.sum(:subtotal_ars).to_f
      nombres = items.group(:nombre).order(Arel.sql('SUM(subtotal_ars) DESC')).limit(5).sum(:subtotal_ars)

      {
        cantidad: items.count,
        total_ars: total,
        top: nombres.map { |nombre, monto| { nombre: nombre, total_ars: monto.to_f } },
      }
    end

    # ── Lecturas del salón: insights accionables (tono good/warn/bad) desde datos reales ──
    def lecturas
      out = []
      total_u = items_hoy.sum(:cantidad).to_f

      # Estrella del día: el más vendido hoy.
      if (top = top_productos.first) && top[:cantidad].positive?
        share = total_u.positive? ? (top[:cantidad] / total_u * 100).round : 0
        margen_txt = top[:margen_pct] ? " y #{top[:margen_pct]}% de margen" : ''
        out << { tono: 'good', texto: "#{top[:nombre]} es tu estrella: #{top[:cantidad].to_i} ventas hoy (#{share}% del total)#{margen_txt}." }
      end

      # Agotado que se vendía: producto sin stock que tuvo ventas este mes.
      agotado = @bar.bar_productos.activos.where('stock <= 0')
                    .find { |p| vendidos_mes_by_id[p.id].to_f.positive? }
      out << { tono: 'bad', texto: "#{agotado.nombre} está agotado y venías vendiéndolo. Reponé para no perder ventas." } if agotado

      # Margen bajo: producto vendido este mes con margen < 50%.
      bajo = @bar.bar_productos.activos
                 .select { |p| p.margen_pct && p.margen_pct < 50 && vendidos_mes_by_id[p.id].to_f.positive? }
                 .min_by(&:margen_pct)
      out << { tono: 'warn', texto: "El margen de #{bajo.nombre} es bajo (#{bajo.margen_pct}%). Revisá el precio o el costo de la mercadería." } if bajo

      # Ventas sueltas repetidas = hay productos que nadie cargó al catálogo. No es un reto al
      # mostrador (hizo lo correcto: cobrar y dejar registro), es trabajo pendiente de gestión.
      sueltas = sueltas_mes
      if sueltas[:cantidad] >= 3
        nombres = sueltas[:top].first(2).map { |x| x[:nombre] }.join(', ')
        out << { tono: 'warn',
                 texto: "#{sueltas[:cantidad]} ventas sueltas este mes por #{fmt_ars(sueltas[:total_ars])} " \
                        "(#{nombres}…). Cargá esos productos al catálogo: así entran al inventario y " \
                        'tenés su margen.' }
      end

      # Tendencia del mes vs mes pasado.
      d = resultado_mes[:delta_pct]
      if d && d.abs >= 5
        out << (d >= 0 ? { tono: 'good', texto: "Vas #{d}% arriba del mes pasado a esta altura. Buen ritmo." }
                       : { tono: 'warn', texto: "Vas #{d.abs}% abajo del mes pasado a esta altura. Ojo con el ritmo del mes." })
      end

      out
    end

    def fmt_ars(n)
      "$#{n.to_i.to_s.reverse.scan(/\d{1,3}/).join('.').reverse}"
    end

    # ── helpers cacheados ──
    def ventas_hoy
      @ventas_hoy ||= @bar.bar_ventas.del_dia(@hoy)
    end

    def items_hoy
      @items_hoy ||= BarVentaItem.where(club_id: @club.id, bar_venta_id: ventas_hoy.select(:id))
    end

    def productos_by_id
      @productos_by_id ||= @bar.bar_productos.with_deleted.index_by(&:id)
    end

    # Unidades vendidas este mes por producto (para insights y para el ranking del mes).
    def vendidos_mes_by_id
      @vendidos_mes_by_id ||= begin
        ventas_mes = @bar.bar_ventas.where(created_at: @hoy.beginning_of_month.beginning_of_day..@hoy.end_of_day)
        BarVentaItem.where(club_id: @club.id, bar_venta_id: ventas_mes.select(:id))
                    .group(:bar_producto_id).sum(:cantidad).transform_values(&:to_f)
      end
    end

    # Margen bruto del día: (ventas − costo mercadería) / ventas, solo sobre líneas con costo conocido.
    def margen_bruto_hoy
      ingreso = 0.0
      costo   = 0.0
      items_hoy.pluck(:bar_producto_id, :cantidad, :subtotal_ars).each do |pid, cant, sub|
        p = productos_by_id[pid]
        next if p.nil? || p.costo_ars.blank?

        ingreso += sub.to_f
        costo   += p.costo_ars.to_f * cant.to_f
      end
      ingreso.positive? ? (((ingreso - costo) / ingreso) * 100).round(1) : nil
    end
  end
end
