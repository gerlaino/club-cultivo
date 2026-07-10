module Sedes
  # Resumen financiero por sede para el cockpit de Sedes: rentabilidad del mes (resultado +
  # tendencia vs mes pasado) y capital inmovilizado (valor de inventario = stock valorizado +
  # insumos del depósito). Todo derivado de datos que ya capturamos (libro contable, Stock, Insumo).
  #
  # El consolidado es la SUMA de las sedes; los movimientos/stock "sin sede" (pool del club) no se
  # atribuyen a ninguna sede y quedan fuera del cockpit (viven en Contabilidad y en el pool).
  class ResumenFinanciero
    def initialize(club, hoy: Time.zone.today)
      @club = club
      @hoy  = hoy
    end

    def call
      rows = @club.sedes.activas.order(:nombre).map { |s| metricas(s) }
      { por_sede: rows, consolidado: consolidar(rows) }
    end

    private

    def metricas(sede)
      movs    = @club.movimientos_contables.por_sede(sede.id)
      ini_mes = @hoy.beginning_of_month
      ing = movs.del_periodo(ini_mes, @hoy).ingresos.sum(:monto_ars).to_f
      egr = movs.del_periodo(ini_mes, @hoy).egresos.sum(:monto_ars).to_f
      resultado = (ing - egr).round(2)

      # Mismo tramo del mes pasado, para la tendencia.
      ini_prev = ini_mes - 1.month
      fin_prev = ini_prev + (@hoy.day - 1).days
      prev = movs.del_periodo(ini_prev, fin_prev)
      prev_res = (prev.ingresos.sum(:monto_ars) - prev.egresos.sum(:monto_ars)).to_f
      delta = prev_res.abs.positive? ? (((resultado - prev_res) / prev_res.abs) * 100).round : nil

      # Capital inmovilizado: stock disponible valorizado + insumos del depósito de la sede.
      stock_ars   = @club.stocks.disponibles.where(sede_id: sede.id)
                         .sum('cantidad * COALESCE(costo_unitario_ars, 0)').to_f.round(2)
      insumos_ars = @club.insumos.de_sede(sede.id)
                         .sum('stock_actual * costo_promedio_ars').to_f.round(2)

      {
        id:             sede.id,
        nombre:         sede.nombre,
        tipo:           sede.tipo,
        ingresos_mes:   ing.round(2),
        egresos_mes:    egr.round(2),
        resultado_mes:  resultado,
        margen_pct:     ing.positive? ? ((resultado / ing) * 100).round(1) : nil,
        delta_pct:      delta,
        inventario_ars: (stock_ars + insumos_ars).round(2),
        stock_ars:      stock_ars,
        insumos_ars:    insumos_ars,
      }
    end

    def consolidar(rows)
      {
        sedes:          rows.size,
        ingresos_mes:   rows.sum { |r| r[:ingresos_mes] }.round(2),
        egresos_mes:    rows.sum { |r| r[:egresos_mes] }.round(2),
        resultado_mes:  rows.sum { |r| r[:resultado_mes] }.round(2),
        inventario_ars: rows.sum { |r| r[:inventario_ars] }.round(2),
        # Sede que más rinde y sede con más capital parado (para el header).
        mejor_resultado: rows.max_by { |r| r[:resultado_mes] }&.slice(:id, :nombre, :resultado_mes),
        mas_inventario:  rows.max_by { |r| r[:inventario_ars] }&.slice(:id, :nombre, :inventario_ars),
      }
    end
  end
end
