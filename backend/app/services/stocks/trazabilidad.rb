module Stocks
  # LA TRAZABILIDAD DE UN FRASCO: de qué plantas salió, qué recibieron, a quién fue, y LA CUENTA.
  #
  # Es lo primero que pide un auditor en una inspección —señala un producto y pregunta de dónde
  # salió— y lo que el admin abre cuando el stock no cuadra. Vivía en `StocksController#trazabilidad`
  # con 200 líneas, y el balance —la única parte que se comprueba con lápiz— estaba mal en tres
  # sentidos que no se veían (sep-2026):
  #
  #   · Las entregas salían de `dispensaciones.stock_id`, que desde la dispensa multi-producto es
  #     LA PRIMERA LÍNEA, con `cantidad` = LA SUMA DE TODAS. Una dispensa de 5 g de A + 3 g de B
  #     figuraba en A con 8 g y en B no figuraba.
  #   · Una dispensa cancelada devuelve el producto al frasco y la lista la seguía contando: el
  #     gramo estaba en «queda» y en «dispensado» a la vez.
  #   · `limit(100)` y el total se sumaba sobre esas cien.
  #
  # Y «merma y otras salidas» se deducía por resta, metiendo en una bolsa ámbar un traslado a otra
  # sede (el mismo producto en otra fila), lo consumido para un derivado y el consumo de un evento
  # —que no son pérdida— junto con la merma, que sí. Cada movimiento tiene tipo: se nombra cada uno,
  # y la resta queda sólo para lo que ningún movimiento explica, que es lo que hay que ir a buscar.
  #
  # Pantalla y PDF leen el MISMO hash: un arreglo acá llega a los dos.
  class Trazabilidad
    # Cuántas entregas viajan a la pantalla. Los totales se calculan sobre TODAS; el PDF pide
    # `completo: true` porque es lo que se entrega, y una lista cortada en cien no acredita nada.
    LISTA_PANTALLA = 100

    # Salidas que se nombran en la cuenta, en el orden en que se muestran: primero lo que sigue
    # existiendo en otra fila, después lo consumido con motivo, la pérdida al final.
    TIPOS_SALIDA = %w[transferencia produccion consumo_evento salida ajuste merma].freeze

    def initialize(stock:, completo: false)
      @stock    = stock
      @completo = completo
    end

    def call
      s = @stock
      lote     = s.lote
      genetica = s.genetica || lote&.genetica
      entregas = entregas_del_frasco
      salidas  = salidas_del_frasco
      cuenta   = cuenta(entregas, salidas)

      {
        stock: {
          id:                    s.id,
          numero_lote_producto:  s.numero_lote_producto,
          forma_producto:        s.forma_producto,
          unidad:                s.unidad,
          origen:                s.origen,
          proveedor:             s.proveedor,
          sede:                  s.sede&.nombre,
          cantidad_inicial_g:    cuenta[:gramos_producidos],
          cantidad_disponible_g: cuenta[:cantidad_disponible_g],
          fecha_elaboracion:     s.fecha_elaboracion,
          codigo_qr:             s.codigo_qr,
          genetica:              genetica && genetica_payload(genetica, completa: true),
          # Un derivado HEREDA la cadena de la flor de la que salió (decisión de Germán, sep-2026):
          # lo que le pusieron a la planta también está en el hash. Acá dice de qué frasco y cuánto.
          producido_desde:       s.producido_desde_stock && {
            id:      s.producido_desde_stock.id,
            numero:  s.producido_desde_stock.numero_lote_producto,
            gramos:  s.lote_origen_consumido_g&.to_f,
          },
        },
        lote: lote && {
          id:       lote.id,
          codigo:   lote.codigo,
          estado:   lote.estado,
          sede:     lote.sede&.nombre,
          sala:     lote.sala&.nombre,
          start_date: lote.start_date,
          dias_en_estado: lote.dias_en_estado,
          genetica: lote.genetica && genetica_payload(lote.genetica),
        },
        aplicaciones:         Lotes::ResumenAplicaciones.new(lote).call,
        analisis_laboratorio: analisis(lote),
        pesada:               pesada_payload,
        plantas:              plantas,
        atribucion:           atribucion,
        plantas_descartadas:  descartadas,
        cronologia:           cronologia(lote),
        siguio_en:            siguio_en,
        salidas:              salidas,
        dispensaciones:       @completo ? entregas : entregas.first(LISTA_PANTALLA),
        dispensaciones_omitidas: @completo ? 0 : [entregas.size - LISTA_PANTALLA, 0].max,
        totales:              cuenta,
        frase:                frase(cuenta, lote),
      }
    end

    private

    # ── Origen ───────────────────────────────────────────────────────────────

    def genetica_payload(g, completa: false)
      base = {
        id:                    g.id,
        # Informe REGULATORIO: va el nombre con el que la organización acredita la variedad. El
        # propio queda al lado para que la traducción sea auditable.
        nombre:                g.nombre_declarado,
        nombre_propio:         g.nombre,
        declarada:             g.declarada_como.present?,
        numero_registro_inase: g.numero_inase_declarado,
      }
      completa ? base.merge(tipo: g.tipo, thc: g.thc, cbd: g.cbd) : base
    end

    # De qué frasco se leen los pesajes: del propio, o del que lo originó si es un derivado.
    def frasco_de_origen
      @frasco_de_origen ||= @stock.producido_desde_stock || @stock
    end

    def pesada = frasco_de_origen.pesada

    # Trazar es decir DE QUÉ PLANTAS salió ESTE frasco, no qué plantas tuvo el lote. Se leen los
    # dos flujos —`PesajeManicura` (por donde entra hoy toda la flor) y la `Pesada` vieja— y si
    # ninguno registró planta por planta se cae al lote, diciéndolo (`atribucion`).
    def pesadas_plantas
      @pesadas_plantas ||= begin
        filas = PesadaPlanta.includes(:plant)
                            .where(pesaje_manicura_id: frasco_de_origen.pesajes_manicura.select(:id)).to_a
        filas += pesada.pesadas_plantas.includes(:plant).to_a if pesada
        filas
      end
    end

    def atribucion
      return 'planta' if pesadas_plantas.any?
      return 'lote'   if @stock.lote

      nil
    end

    def plantas
      @plantas ||= if pesadas_plantas.any?
        # Una planta puede aparecer en más de un pesaje del mismo contenedor: va una sola vez,
        # con la suma. El peso que vale es el SECO; el húmedo queda de respaldo.
        pesadas_plantas.group_by(&:plant_id).map do |plant_id, filas|
          planta = filas.first.plant
          pesos  = filas.filter_map { |pp| (pp.peso_seco_g || pp.peso_humedo_g)&.to_f }
          { id: plant_id, nombre: planta&.nombre, codigo_qr: planta&.codigo_qr, origen: planta&.origen,
            peso_g:   pesos.any? ? pesos.sum.round(2) : nil,
            promedio: filas.any?(&:es_promedio) }
        end
      elsif @stock.lote
        # Sin descartadas: una planta que no produjo no es origen de nada. Van aparte.
        @stock.lote.plants.where.not(state: 'descartada')
              .map { |p| { id: p.id, nombre: p.nombre, codigo_qr: p.codigo_qr, origen: p.origen, peso_g: nil } }
      else
        []
      end
    end

    def descartadas
      return [] unless @stock.lote

      @stock.lote.plants.where(state: 'descartada').map do |p|
        { id: p.id, nombre: p.nombre, codigo_qr: p.codigo_qr, motivo_descarte: p.motivo_descarte }
      end
    end

    def pesada_payload
      return nil unless pesada

      { id: pesada.id, fase_destino: pesada.fase_destino, peso_total_g: pesada.peso_total_g&.to_f,
        registrado_at: pesada.registrado_at, plantas_count: plantas.size }
    end

    def analisis(lote)
      return [] unless lote

      lote.analisis_laboratorio.order(fecha_analisis: :desc).map do |a|
        { fecha: a.fecha_analisis, laboratorio: a.laboratorio,
          thc_pct: a.thc_pct&.to_f, cbd_pct: a.cbd_pct&.to_f, cbg_pct: a.cbg_pct&.to_f,
          terpenos: a.terpenos_principales }
      end
    end

    # ── Cronología ───────────────────────────────────────────────────────────

    # Las fechas del ciclo, en orden: cada cambio de estado del lote con los días que llevó el
    # anterior, las plantas descartadas cuando se descartaron, los pesajes que alimentaron ESTE
    # frasco. La pantalla ya la dibujaba leyendo `lote_eventos`, que el backend nunca mandó: la
    # línea de tiempo mostró sólo la pesada durante meses.
    # La cronología es del LOTE y la comparte la trazabilidad del lote (`Lotes::Trazabilidad`).
    def cronologia(lote)
      Lotes::Cronologia.new(lote, pesajes: frasco_de_origen.pesajes_manicura.confirmados,
                                  pesada: pesada, plantas_count: plantas.size).call
    end

    # ── A quién fue ──────────────────────────────────────────────────────────

    # Por LÍNEA (`DispensacionItem`), que es donde está la cantidad de ESTE frasco. Las dispensas
    # de antes del carrito no tienen líneas: esas se leen por `stock_id`, y sólo esas. Canceladas
    # afuera: lo que volvió al frasco no salió.
    def entregas_del_frasco
      @entregas ||= begin
        con_linea = DispensacionItem.joins(:dispensacion)
                                    .where(stock_id: @stock.id)
                                    .merge(Dispensacion.no_canceladas)
                                    .includes(dispensacion: [:paciente, :sede, { items: :stock }])
                                    .to_a
        con_ids = con_linea.map(&:dispensacion_id)
        legacy  = Dispensacion.no_canceladas.where(stock_id: @stock.id).where.not(id: con_ids)
                              .where.not(id: DispensacionItem.select(:dispensacion_id))
                              .includes(:paciente, :sede).to_a

        filas = con_linea.map { |it| entrega(it.dispensacion, it.cantidad, it) } +
                legacy.map    { |d|  entrega(d, d.cantidad, nil) }
        filas.sort_by { |f| [f[:fecha] ? 0 : 1, f[:fecha] || Date.new(1970)] }.reverse
      end
    end

    def entrega(d, cantidad, item)
      pac = d.paciente
      junto_con = item ? d.items.reject { |o| o.id == item.id }.filter_map { |o| o.stock&.numero_lote_producto } : []
      {
        id:         d.id,
        fecha:      d.fecha_dispensacion,
        cantidad_g: cantidad&.to_f,
        # Nombre completo: la trazabilidad se lee para saber a quién le llegó cada gramo, y dos
        # iniciales no acreditan a nadie. El DNI va PARCIAL en pantalla (últimos tres, como el
        # resto de los informes) y COMPLETO sólo en el PDF, que es lo que se entrega (decisión de
        # Germán, sep-2026).
        paciente:           pac&.nombre_completo,
        paciente_iniciales: "#{pac&.nombre&.[](0)}.#{pac&.apellido&.[](0)}.",
        paciente_dni_last3: pac&.dni_normalizado.to_s.last(3),
        paciente_dni:       @completo ? pac&.dni_normalizado.to_s : nil,
        canal:              canal(d),
        junto_con:          junto_con,
      }
    end

    def canal(d)
      if d.con_envio
        "envío · #{d.estado_envio.to_s.tr('_', ' ')}"
      elsif d.sede
        "mostrador #{d.sede.nombre}"
      else
        'mostrador'
      end
    end

    # ── Salió por otro lado ──────────────────────────────────────────────────

    # Cada salida con su tipo y, cuando el producto sigue existiendo, a dónde: un traslado nombra
    # la fila destino y un derivado el frasco que se elaboró. Los `dispensacion` no van: las
    # entregas ya se cuentan por línea. Un ajuste positivo es una ENTRADA y se lista como tal.
    def salidas_del_frasco
      @salidas ||= begin
        movs = @stock.stock_movimientos.where(tipo: TIPOS_SALIDA)
                     .includes(:stock_resultante, :sede_destino).order(:fecha, :created_at).to_a
        sueltos, de_cierre = movs.partition { |m| m.tipo != 'ajuste' || m.turno_mostrador_id.nil? }
        sueltos.map { |m| salida(m) } + ajustes_neteados(de_cierre)
      end
    end

    def salida(m)
      dest = m.stock_resultante
      {
        id:      m.id,
        tipo:    m.tipo,
        gramos:  m.gramos.to_f.round(2),
        fecha:   m.fecha || m.created_at&.to_date,
        detalle: m.notas.to_s.sub(/\A\[PRODUCCIÓN\]\s*/, '').presence,
        destino: dest && { id: dest.id, numero: dest.numero_lote_producto, forma: dest.forma_producto,
                           sede: (m.sede_destino || dest.sede)&.nombre },
      }
    end

    # LOS AJUSTES DE CONTEO SE NETEAN POR CIERRE (Germán, sep-2026). Contar 21 donde había 215 y
    # corregirlo después deja dos movimientos —−194 y +194— para un producto que no se movió:
    # listarlos es contar un error de tipeo como salida y luego como entrada. Se suman por cierre
    # y por frasco; si el neto es cero no aparecen (quedan en el historial del mostrador, que es
    # donde importa quién contó qué). Si queda diferencia, una sola línea con el cierre.
    def ajustes_neteados(movs)
      movs.group_by(&:turno_mostrador_id).filter_map do |turno_id, ms|
        neto = ms.sum { |m| m.gramos.to_d }.round(2)
        next if neto.zero?

        ultimo = ms.max_by { |m| [m.fecha || m.created_at.to_date, m.created_at] }
        { id: "cierre-#{turno_id}", tipo: 'ajuste', gramos: neto.to_f,
          fecha: ultimo.fecha || ultimo.created_at&.to_date,
          detalle: "diferencia de conteo del cierre del #{(ms.first.fecha || ms.first.created_at.to_date).strftime('%d/%m')}",
          destino: nil }
      end
    end

    # Dónde continúa la cadena: los frascos que nacieron de éste, por traslado o por elaboración.
    def siguio_en
      salidas_del_frasco.filter_map do |s|
        next unless s[:destino]

        { stock_id: s[:destino][:id], numero: s[:destino][:numero], forma: s[:destino][:forma],
          sede: s[:destino][:sede], tipo: s[:tipo] == 'produccion' ? 'derivado' : 'traslado',
          gramos: s[:gramos].abs }
      end
    end

    # ── La cuenta ────────────────────────────────────────────────────────────

    def cuenta(entregas, salidas)
      inicial     = @stock.cantidad_inicial.to_f.round(2)
      disponible  = @stock.cantidad.to_f.round(2)
      dispensado  = entregas.sum { |e| e[:cantidad_g].to_f }.round(2)
      salio       = salidas.select { |s| s[:gramos].negative? }.sum { |s| s[:gramos].abs }.round(2)
      entro       = salidas.select { |s| s[:gramos].positive? }.sum { |s| s[:gramos] }.round(2)
      merma       = salidas.select { |s| s[:tipo] == 'merma' }.sum { |s| s[:gramos].abs }.round(2)
      sin_explicar = (inicial + entro - dispensado - salio - disponible).round(2)
      # Sobre la mesa de un mostrador o en el depósito: «queda 97,5 g» no le alcanza al que va a
      # buscar el frasco.
      en_mesa = @stock.mostrador_items.con_stock.sum(:cantidad).to_f.round(2)

      {
        plantas_origen:        plantas.size,
        plantas_descartadas:   descartadas.size,
        dispensaciones_count:  entregas.size,
        gramos_producidos:     inicial,
        gramos_dispensados:    dispensado,
        cantidad_disponible_g: disponible,
        en_mesa_g:             [en_mesa, disponible].min,
        en_deposito_g:         [disponible - en_mesa, 0].max.round(2),
        otras_salidas_g:       salio,
        entradas_g:            entro,
        merma_g:               merma,
        # Lo que ningún movimiento explica. Se tolera el redondeo de dos decimales.
        sin_explicar_g:        sin_explicar.abs < 0.01 ? 0.0 : sin_explicar,
        pct_dispensado:        inicial.positive? ? ((dispensado / inicial) * 100).round(1) : 0,
      }
    end

    # La cuenta en una oración, para leer en voz alta delante del auditor. Misma regla que la
    # ficha de un cierre del mostrador: el número con sujeto y verbo, y al final si cierra.
    def frase(t, lote)
      u = @stock.unidad.presence || 'g'
      n = ->(v) { ActiveSupport::NumberHelper.number_to_delimited(v.round(1).to_s.sub(/\.0\z/, ''), delimiter: '.', separator: ',') }
      partes = []
      origen = if @stock.producido_desde_stock
                 "de #{n.call(@stock.lote_origen_consumido_g.to_f)} g de #{@stock.producido_desde_stock.numero_lote_producto}"
               elsif t[:plantas_origen].positive? && lote
                 "de #{t[:plantas_origen]} plantas del lote #{lote.codigo}"
               elsif lote
                 "del lote #{lote.codigo}"
               elsif @stock.proveedor.present?
                 "comprados a #{@stock.proveedor}"
               end
      partes << "Entraron #{n.call(t[:gramos_producidos])} #{u}#{origen && " #{origen}"}."
      partes << "#{n.call(t[:gramos_dispensados])} #{u} fueron a #{t[:dispensaciones_count]} #{t[:dispensaciones_count] == 1 ? 'entrega' : 'entregas'}." if t[:gramos_dispensados].positive?
      salidas_del_frasco.select { |s| s[:gramos].negative? }.group_by { |s| s[:tipo] }.each do |tipo, ss|
        g = n.call(ss.sum { |s| s[:gramos].abs })
        partes << case tipo
                  when 'transferencia' then "#{g} #{u} siguen en #{ss.filter_map { |s| s[:destino]&.[](:numero) }.uniq.join(', ').presence || 'otra sede'}."
                  when 'produccion'    then "#{g} #{u} se convirtieron en #{ss.filter_map { |s| s[:destino]&.[](:numero) }.uniq.join(', ').presence || 'un derivado'}."
                  when 'consumo_evento' then "#{g} #{u} se consumieron en un evento."
                  when 'salida'        then "#{g} #{u} salieron (#{ss.filter_map { |s| s[:detalle] }.uniq.join('; ').presence || 'sin motivo anotado'})."
                  when 'ajuste'        then "#{g} #{u} se ajustaron en un conteo."
                  when 'merma'         then "#{g} #{u} son merma."
                  end
      end
      partes << "Quedan #{n.call(t[:cantidad_disponible_g])} #{u}."
      partes << if t[:sin_explicar_g].zero?
                  'La cuenta cierra.'
                elsif t[:sin_explicar_g].positive?
                  "Faltan #{n.call(t[:sin_explicar_g])} #{u} que ningún movimiento explica."
                else
                  "Sobran #{n.call(t[:sin_explicar_g].abs)} #{u} que ningún movimiento explica."
                end
      partes.join(' ')
    end
  end
end
