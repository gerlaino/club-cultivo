module Informes
  # EL INFORME DE PÉRDIDAS contesta dos preguntas del período: qué NO LLEGÓ A COSECHA (plantas
  # descartadas, por motivo, por lote) y qué SE PERDIÓ DESPUÉS (producto que salió del inventario
  # sin entregarse). Cada cosa por unidad, con lo que costó producirla al lado —es lo único que
  # hace comparable 38 g de flor con 4 prerolls— y comparada con el período anterior.
  #
  # Vivía en el controller y contaba mal en tres lugares (sep-2026): los descartes por `updated_at`
  # (corregirle el motivo a una planta descartada en marzo la traía al mes de hoy), la merma sumando
  # `gramos` de todos los stocks (4 prerolls entraban como 4 gramos) y los ajustes de conteo del
  # mostrador uno por uno, con lo que un dedazo corregido —−194 y +194— contaba como pérdida.
  # No hay «stock vencido»: no existe en esta organización (Germán, sep-2026).
  class Perdidas
    LISTA_PANTALLA = 100

    def initialize(club:, desde:, hasta:)
      @club  = club
      @desde = desde
      @hasta = hasta
    end

    def call
      duracion = (@hasta.to_date - @desde.to_date).to_i + 1
      d_ant = @desde - duracion.days
      h_ant = @desde - 1.second

      plantas     = plantas_en(@desde, @hasta)
      plantas_ant = plantas_en(d_ant, h_ant)
      producto     = producto_en(@desde, @hasta)
      producto_ant = producto_en(d_ant, h_ant)

      {
        plantas:  resumen_plantas(plantas, plantas_ant),
        producto: resumen_producto(producto, producto_ant),
      }
    end

    # ── 1. Lo que no llegó a cosecha ─────────────────────────────────────────

    # Por la fecha en que PASÓ: la actividad del descarte (`PlantActivity`), nunca `updated_at`.
    # Sin actividad (descartes viejos, o cargados por fuera) se cae a `updated_at` y la fila lo dice.
    # Sin join por sala: una planta descartada es del lote, esté donde esté.
    def plantas_en(desde, hasta)
      lotes_ids = @club.lotes.select(:id)
      descartadas = Plant.where(lote_id: lotes_ids, state: 'descartada').includes(lote: [:genetica, :costo_lote]).to_a
      fechas = PlantActivity.where(plant_id: descartadas.map(&:id), activity_type: 'state_change')
                            .where("description ILIKE 'Descartada%'")
                            .group(:plant_id).minimum(:occurred_at)
      descartadas.filter_map do |p|
        fecha = fechas[p.id]
        estimada = fecha.nil?
        fecha ||= p.updated_at
        next unless fecha && fecha >= desde && fecha <= hasta

        { id: p.id, nombre: p.nombre, lote_id: p.lote_id, lote: p.lote&.codigo, genetica: p.lote&.genetica&.nombre,
          motivo: p.motivo_descarte.presence || 'sin_motivo', fecha: fecha.to_date, fecha_estimada: estimada,
          costo_ars: costo_por_planta(p.lote) }
      end
    end

    # Lo que costó producir el lote, prorrateado por planta. Sin costo cargado, nil: no se inventa.
    def costo_por_planta(lote)
      return nil unless lote&.costo_lote&.costo_total.to_f.positive? && lote.plants_count.to_i.positive?

      (lote.costo_lote.costo_total.to_f / lote.plants_count).round(2)
    end

    def resumen_plantas(actual, anterior)
      en_cultivo = Plant.en_pie.where(lote_id: @club.lotes.select(:id)).count
      con_costo  = actual.select { |p| p[:costo_ars] }
      por_motivo = actual.group_by { |p| p[:motivo] }.map do |motivo, ps|
        { motivo: motivo, plantas: ps.size,
          lotes: ps.group_by { |p| p[:lote] }.map { |l, xs| { codigo: l, plantas: xs.size } }.sort_by { |x| -x[:plantas] },
          ultima: ps.map { |p| p[:fecha] }.max }
      end.sort_by { |m| -m[:plantas] }

      {
        total:     actual.size,
        anterior:  anterior.size,
        en_cultivo: en_cultivo,
        porcentaje: (actual.size + en_cultivo).positive? ? ((actual.size.to_f / (actual.size + en_cultivo)) * 100).round(1) : 0.0,
        costo_ars:  con_costo.sum { |p| p[:costo_ars] }.round(2),
        sin_costo:  actual.size - con_costo.size,
        por_motivo: por_motivo,
        lista:      actual.sort_by { |p| [p[:fecha], p[:lote].to_s] }.reverse.first(LISTA_PANTALLA),
        omitidas:   [actual.size - LISTA_PANTALLA, 0].max,
      }
    end

    # ── 2. Lo que se perdió después ──────────────────────────────────────────

    # Por línea, con su frasco y su unidad: la merma declarada (con la nota escrita al declararla)
    # y las diferencias de conteo del mostrador NETEADAS por cierre y frasco —un error corregido
    # no aparece— más los ajustes en menos que no son del mostrador. Nunca una suma cruzada.
    def producto_en(desde, hasta)
      movs = StockMovimiento.joins(:stock).where(stocks: { club_id: @club.id })
                            .where(tipo: %w[merma ajuste]).en_periodo(desde, hasta)
                            .includes(stock: :genetica).to_a
      merma   = movs.select { |m| m.tipo == 'merma' && m.gramos.to_d.negative? }
      ajustes = movs.select { |m| m.tipo == 'ajuste' }
      de_mostrador, sueltos = ajustes.partition(&:turno_mostrador_id)

      filas = merma.map { |m| fila(m.stock, m.gramos.to_d.abs, 'Merma declarada', m.notas, m.fecha || m.created_at&.to_date) }
      filas += sueltos.select { |m| m.gramos.to_d.negative? }
                      .map { |m| fila(m.stock, m.gramos.to_d.abs, 'Ajuste de inventario', m.notas, m.fecha || m.created_at&.to_date) }
      # Neto por frasco de todos sus cierres del período: negativo = faltó.
      de_mostrador.group_by(&:stock_id).each do |_, ms|
        neto = ms.sum { |m| m.gramos.to_d }
        next unless neto.negative?

        cierres = ms.map(&:turno_mostrador_id).uniq.size
        filas << fila(ms.first.stock, neto.abs, "Diferencias de conteo del mostrador, #{cierres} #{cierres == 1 ? 'cierre' : 'cierres'} (neto)",
                      nil, ms.map { |m| m.fecha || m.created_at&.to_date }.compact.max, mostrador: true)
      end
      filas
    end

    def fila(stock, cantidad, que_paso, detalle, fecha, mostrador: false)
      costo = stock&.costo_unitario_ars.to_f
      {
        stock_id: stock&.id, frasco: stock&.numero_lote_producto, genetica: stock&.genetica&.nombre,
        forma: stock&.forma_producto || 'otro', unidad: stock&.unidad.presence || 'g',
        que_paso: que_paso, detalle: detalle.presence, fecha: fecha, mostrador: mostrador,
        cantidad: cantidad.to_f.round(2),
        costo_ars: costo.positive? ? (costo * cantidad.to_f).round(2) : nil,
      }
    end

    def resumen_producto(actual, anterior)
      por_u = ->(fs) { fs.group_by { |f| f[:unidad] }.transform_values { |xs| xs.sum { |f| f[:cantidad] }.round(2) } }
      u_act = por_u.call(actual)
      u_ant = por_u.call(anterior)
      {
        por_unidad: u_act.map { |u, c| { unidad: u, cantidad: c, anterior: u_ant[u] } },
        merma_por_unidad:     por_u.call(actual.select { |f| f[:que_paso] == 'Merma declarada' }).map { |u, c| { unidad: u, cantidad: c } },
        mostrador_por_unidad: por_u.call(actual.select { |f| f[:mostrador] }).map { |u, c| { unidad: u, cantidad: c } },
        costo_ars:  actual.sum { |f| f[:costo_ars].to_f }.round(2),
        sin_costo:  actual.count { |f| f[:costo_ars].nil? },
        lista:      actual.sort_by { |f| [-(f[:costo_ars] || 0), -f[:cantidad]] }.first(LISTA_PANTALLA),
        omitidas:   [actual.size - LISTA_PANTALLA, 0].max,
      }
    end
  end
end
