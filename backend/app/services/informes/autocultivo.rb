module Informes
  # «MIS INFORMES» DEL AUTOCULTIVO (9-oct-2026, Germán). Tres preguntas de quien cultiva en casa, con
  # sus palabras —plantas y frascos, no lotes ni sedes—, sobre los mismos datos de siempre:
  #
  #   · Mi cosecha       — ¿cuánto rindió cada planta y cada genética?
  #   · De dónde salió   — cada frasco con su planta, su genética y su QR.
  #   · Mis gastos       — ¿cuánto puse y cuánto me costó cada gramo?
  #
  # Una planta COSECHADA es la que tiene `fecha_cosecha` en el período (se cosecha de a una:
  # `cosechar_plantas`) o, si no la tiene, la de un lote que se cosechó en el período —el lote entero
  # pasa a cosecha sin escribirle la fecha a cada planta, y una carga «ya cosechado» tampoco—. Es el
  # mismo criterio que el informe de producción (`Produccion#cosechado_en`): el primer paso del lote
  # a post-cosecha, nunca `updated_at`. Una cosecha sin plantas cargadas aparece igual, con sus gramos. Los gramos son del LOTE (lo que se pesa al secar y al curar); cuando
  # varias plantas se cargaron juntas y se pesaron juntas, a cada una le toca su parte y se dice
  # («repartido»). Un número que parece de la planta y es un promedio, sin aclararlo, es el peor error.
  class Autocultivo
    def initialize(club:, desde:, hasta:)
      @club  = club
      @desde = desde.to_date
      @hasta = hasta.to_date
    end

    # ── Mi cosecha ──────────────────────────────────────────────────────────────────────────
    def mi_cosecha
      return @mi_cosecha if @mi_cosecha

      fechas = fechas_de_cosecha
      lotes_del_periodo = fechas.select { |_, f| f.between?(@desde, @hasta) }.keys
      plantas = Plant.joins(:lote).where(lotes: { club_id: @club.id }).where.not(state: 'descartada')
                     .where('plants.fecha_cosecha BETWEEN :d AND :h OR (plants.fecha_cosecha IS NULL AND plants.lote_id IN (:ids))',
                            d: @desde, h: @hasta, ids: lotes_del_periodo.presence || [0])
                     .includes(lote: [:genetica, :pesadas]).to_a
      filas = plantas.map { |p| fila_planta(p, fechas[p.lote_id]) }
      # Cosechas sin ninguna planta cargada: el lote solo, para que sus gramos no desaparezcan.
      con_plantas = plantas.map(&:lote_id).uniq
      Lote.where(id: lotes_del_periodo - con_plantas).includes(:genetica, :pesadas).each do |l|
        filas << fila_lote_sin_plantas(l, fechas[l.id])
      end
      filas.sort_by! { |f| [f[:cosechada] || @hasta, f[:nombre]] }
      con_seco = filas.select { |f| f[:seco_g] }
      seco = con_seco.sum { |f| f[:seco_g] }.round(1)
      por_genetica = filas.group_by { |f| f[:genetica] }.map do |g, fs|
        pesadas = fs.select { |f| f[:seco_g] }
        total = pesadas.sum { |f| f[:seco_g] }.round(1)
        { genetica: g, plantas: fs.size, seco_g: pesadas.any? ? total : nil,
          por_planta_g: pesadas.any? ? (total / pesadas.size).round(1) : nil }
      end.sort_by { |g| -(g[:por_planta_g] || 0) }

      {
        plantas: filas, por_genetica: por_genetica,
        total_plantas: filas.size, seco_g: seco, sin_peso: filas.size - con_seco.size,
        por_planta_g: con_seco.any? ? (seco / con_seco.size).round(1) : nil,
      }.tap { |r| @mi_cosecha = r }
    end

    # ── De dónde salió ──────────────────────────────────────────────────────────────────────
    # Cada frasco (stock con lote) del período, hasta la planta y la genética.
    def de_donde_salio
      stocks = Stock.where(club_id: @club.id).where.not(lote_id: nil)
                    .where(created_at: @desde.beginning_of_day..@hasta.end_of_day)
                    .includes(:genetica, lote: [:genetica, :plants]).order(:created_at).to_a
      frascos = stocks.map do |s|
        cosechadas = s.lote.plants.reject { |p| p.state == 'descartada' }.sort_by(&:nombre)
        {
          codigo: s.codigo_qr.presence || "##{s.id}",
          producto: s.descripcion.presence || s.forma_producto.to_s.tr('_', ' ').capitalize,
          gramos: (s.cantidad_inicial || s.cantidad).to_f.round(1),
          unidad: s.unidad,
          quedan: s.cantidad.to_f.round(1),
          plantas: cosechadas.map(&:nombre),
          genetica: (s.genetica || s.lote.genetica)&.nombre,
          cosechada: cosechadas.filter_map(&:fecha_cosecha).min || fechas_de_cosecha[s.lote_id],
          qr_plantas: cosechadas.filter_map(&:codigo_qr),
        }
      end
      { frascos: frascos, total_frascos: frascos.size,
        gramos: frascos.select { |f| f[:unidad] == 'g' }.sum { |f| f[:gramos] }.round(1),
        plantas_de_origen: frascos.flat_map { |f| f[:plantas] }.uniq.size }
    end

    # ── Mis gastos ──────────────────────────────────────────────────────────────────────────
    # Lo que se anotó como gasto (egresos), por mes y por tipo, contra lo que se cosechó en el
    # mismo período. «Cada gramo» es la cuenta del período; por cosecha, la de los gastos que se
    # asignaron a esas plantas.
    def mis_gastos
      gastos = MovimientoContable.where(club_id: @club.id).egresos.where(fecha: @desde..@hasta)
                                 .includes(:categoria_contable).to_a
      tipo_de = ->(g) { g.categoria_contable&.nombre.presence || g.categoria.to_s.tr('_', ' ').capitalize }
      tipos = gastos.group_by(&tipo_de).transform_values { |gs| gs.sum(&:monto_ars).to_f }
                    .sort_by { |_, m| -m }.map(&:first)
      por_mes = gastos.group_by { |g| g.fecha.beginning_of_month }.sort.map do |mes, gs|
        { mes: mes, por_tipo: tipos.to_h { |t| [t, gs.select { |g| tipo_de.call(g) == t }.sum(&:monto_ars).to_f] },
          total: gs.sum(&:monto_ars).to_f }
      end
      total = gastos.sum(&:monto_ars).to_f
      seco = mi_cosecha[:seco_g]

      lotes = Lote.where(club_id: @club.id, id: gastos.filter_map(&:lote_id).uniq).includes(:genetica, :plants)
      por_cosecha = lotes.map do |l|
        monto = gastos.select { |g| g.lote_id == l.id }.sum(&:monto_ars).to_f
        g = l.rendimiento_real_g.to_f
        { plantas: l.plants.map(&:nombre).sort, genetica: l.genetica&.nombre, gastado: monto,
          gramos: g.positive? ? g.round(1) : nil, por_gramo: g.positive? ? (monto / g).round : nil }
      end

      {
        tipos: tipos, por_mes: por_mes, por_cosecha: por_cosecha, total: total, seco_g: seco,
        por_gramo: seco.to_f.positive? ? (total / seco).round : nil,
        mes_mas_caro: por_mes.max_by { |m| m[:total] }&.dig(:mes),
      }
    end

    private

    # El día en que cada lote se cosechó: su primer paso a post-cosecha.
    def fechas_de_cosecha
      @fechas_de_cosecha ||= LoteEvento.where(club_id: @club.id, tipo: 'cambio_estado', estado_nuevo: Produccion::POST_COSECHA)
                                       .group(:lote_id).minimum(:registrado_en).transform_values { |t| t.in_time_zone.to_date }
    end

    def fila_lote_sin_plantas(l, fecha)
      g = l.rendimiento_real_g.to_f
      humedo = l.pesadas.select { |x| x.fase_destino == 'cosecha' }.sum { |x| x.peso_humedo_g.to_f }
      inicio = l.fecha_inicio_vegetativo || l.start_date
      { nombre: "#{l.genetica&.nombre || 'Cosecha'} (sin plantas cargadas)", genetica: l.genetica&.nombre || 'Sin genética',
        tipo: l.automatica? ? 'Auto' : 'Foto', cosechada: fecha, dias: inicio && fecha ? (fecha - inicio.to_date).to_i : nil,
        humedo_g: humedo.positive? ? humedo.round(1) : nil, seco_g: g.positive? ? g.round(1) : nil, repartido: false }
    end

    def fila_planta(p, fecha_lote = nil)
      l = p.lote
      cosechadas = [l.plants_count_cosechadas.to_i, l.plants.count { |x| x.state != 'descartada' && (x.fecha_cosecha || fecha_lote) }, 1].max
      repartido = cosechadas > 1 && p.peso_seco.blank?
      seco = if p.peso_seco.present? then p.peso_seco.to_f
             elsif l.rendimiento_real_g.to_f.positive? then l.rendimiento_real_g.to_f / cosechadas
             end
      humedo_lote = l.pesadas.select { |x| x.fase_destino == 'cosecha' }.sum { |x| x.peso_humedo_g.to_f }
      humedo = humedo_lote.positive? ? humedo_lote / cosechadas : nil
      inicio = l.fecha_inicio_vegetativo || l.start_date
      {
        nombre: p.nombre,
        genetica: l.genetica&.nombre || 'Sin genética',
        tipo: l.automatica? ? 'Auto' : 'Foto',
        cosechada: p.fecha_cosecha || fecha_lote,
        dias: inicio && (p.fecha_cosecha || fecha_lote) ? ((p.fecha_cosecha || fecha_lote) - inicio.to_date).to_i : nil,
        humedo_g: humedo&.round(1),
        seco_g: seco&.round(1),
        repartido: repartido && (seco || humedo).present?,
      }
    end
  end
end
