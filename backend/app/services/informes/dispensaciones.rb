module Informes
  # EL INFORME DE DISPENSACIONES contesta tres preguntas del período elegido: QUÉ salió (por
  # unidad, comparado con el período anterior), A QUIÉN (una fila por paciente, completa) y POR
  # DÓNDE (mostrador de cada sede, o envío).
  #
  # Vivía en `InformesController#dispensaciones` y contaba mal en dos sentidos que ya conocemos
  # del módulo: sumaba `dispensaciones.cantidad` —la suma de todas las líneas en la unidad de cada
  # una, así que 12 prerolls entraban como 12 gramos al KPI principal— y leía genética y producto
  # de `stock_id`, que desde la dispensa multi-producto es LA PRIMERA LÍNEA: quien se llevó flor y
  # hash figuraba sólo con flor. Y la lista por paciente cortaba en 100 sin decirlo, también en el
  # PDF.
  #
  # Todo se cuenta desde las LÍNEAS (`DispensacionItem`), cada una con su stock, su genética y su
  # unidad, y las cantidades van SIEMPRE agrupadas por unidad: gramos, unidades, ml. Nunca una suma
  # cruzada. (Decisiones de Germán, sep-2026: los regalos siguen contando, con su línea; la tabla
  # de producto es forma × genética; «nuevo» es primera vez en la organización; un envío que
  # todavía no llegó cuenta como salida y la fila lo dice.)
  class Dispensaciones
    LISTA_PANTALLA = 100

    Linea = Struct.new(:dispensacion, :stock, :cantidad, :genetica, :forma, :unidad, keyword_init: true)

    def initialize(club:, desde:, hasta:)
      @club  = club
      @desde = desde
      @hasta = hasta
    end

    def call
      lineas   = lineas_en(@desde, @hasta)
      duracion = (@hasta.to_date - @desde.to_date).to_i + 1
      anterior = lineas_en(@desde - duracion.days, @desde - 1.second)

      {
        salio:     salio(lineas, anterior),
        productos: productos(lineas, anterior),
        pacientes: pacientes(lineas),
        canales:   canales(lineas),
      }
    end

    # ── Las líneas del período ───────────────────────────────────────────────

    # Por línea, sin canceladas. Una dispensa de antes del carrito que no tenga líneas se lee por
    # `stock_id`/`cantidad`, como una línea sola. Si el stock se borró queda el snapshot de la
    # dispensa (`producto_snapshot`) para la forma y la unidad, y `genetica_nombre` de la línea.
    def lineas_en(desde, hasta)
      disps = Dispensacion.no_canceladas
                          .where(paciente_id: Paciente.unscoped.where(club_id: @club.id).select(:id))
                          .where(fecha_dispensacion: desde..hasta)
                          .includes(:paciente, :sede, items: { stock: :genetica })
      disps.flat_map do |d|
        items = d.items.to_a
        if items.any?
          items.map { |it| linea(d, it.stock, it.cantidad, it.genetica_nombre) }
        elsif d.cantidad.to_d.positive?
          [linea(d, d.stock, d.cantidad, d.genetica_nombre)]
        else
          []
        end
      end
    end

    def linea(d, stock, cantidad, genetica_nombre)
      snap = d.producto_snapshot || {}
      Linea.new(
        dispensacion: d, stock: stock, cantidad: cantidad.to_d,
        genetica: genetica_nombre.presence || stock&.genetica&.nombre || stock&.lote&.genetica&.nombre || 'Sin genética',
        forma:    stock&.forma_producto || snap['forma_producto'] || 'otro',
        unidad:   stock&.unidad.presence || snap['unidad'].presence || 'g',
      )
    end

    # ── 1. Lo que salió ──────────────────────────────────────────────────────

    # Por unidad, comparado con el período anterior. Los regalos cuentan —salieron, y la
    # trazabilidad los lista— y se dicen aparte: sin esa línea el admin ve gramos que no cobró y no
    # sabe por qué.
    def salio(lineas, anterior)
      disps  = lineas.map(&:dispensacion).uniq
      prev   = anterior.map(&:dispensacion).uniq
      pacs   = disps.map(&:paciente_id).uniq
      {
        por_unidad:  por_unidad(lineas).map { |u, c|
          a = por_unidad(anterior)[u]
          { unidad: u, cantidad: c, anterior: a, variacion: variacion(c, a) }
        },
        entregas:    { valor: disps.size, anterior: prev.size, variacion: variacion(disps.size, prev.size) },
        pacientes:   { valor: pacs.size, anterior: prev.map(&:paciente_id).uniq.size },
        nuevos:      nuevos(pacs),
        regalos:     por_unidad(lineas.select { |l| l.dispensacion.es_regalo }).map { |u, c| { unidad: u, cantidad: c } },
        regalos_entregas: disps.count(&:es_regalo),
      }
    end

    def por_unidad(lineas)
      lineas.group_by(&:unidad).transform_values { |ls| ls.sum(&:cantidad).round(2).to_f }
    end

    # Primera vez en la ORGANIZACIÓN, no en el período: es el dato de crecimiento.
    def nuevos(paciente_ids)
      return 0 if paciente_ids.empty?

      primeras = Dispensacion.no_canceladas.where(paciente_id: paciente_ids)
                             .group(:paciente_id).minimum(:fecha_dispensacion)
      primeras.count { |_, f| f && f >= @desde.to_date }
    end

    def variacion(actual, anterior)
      return nil if anterior.nil? || anterior.to_f <= 0

      (((actual.to_f - anterior.to_f) / anterior.to_f) * 100).round(1)
    end

    # ── 2. Por producto ──────────────────────────────────────────────────────

    # Forma × genética, con el subtotal por forma delante. Ordenado por entregas.
    def productos(lineas, anterior)
      ant = anterior.group_by { |l| [l.forma, l.genetica] }.transform_values { |ls| ls.sum(&:cantidad).round(2).to_f }
      por_forma = lineas.group_by(&:forma)

      por_forma.sort_by { |_, ls| -ls.map(&:dispensacion).uniq.size }.map do |forma, ls|
        filas = ls.group_by(&:genetica).sort_by { |_, gs| -gs.map(&:dispensacion).uniq.size }.map do |gen, gs|
          cant = gs.sum(&:cantidad).round(2).to_f
          a    = ant[[forma, gen]]
          { genetica: gen, entregas: gs.map(&:dispensacion).uniq.size, cantidad: cant,
            pacientes: gs.map { |l| l.dispensacion.paciente_id }.uniq.size,
            anterior: a, variacion: variacion(cant, a) }
        end
        {
          forma:     forma,
          unidad:    ls.first.unidad,
          entregas:  ls.map(&:dispensacion).uniq.size,
          cantidad:  ls.sum(&:cantidad).round(2).to_f,
          pacientes: ls.map { |l| l.dispensacion.paciente_id }.uniq.size,
          geneticas: filas,
        }
      end
    end

    # ── 3. A quién ───────────────────────────────────────────────────────────

    # Una fila por paciente, COMPLETA (el que corta es el llamador: la pantalla lista 100 y dice
    # cuántos más; el PDF y el Excel llevan todas). Ordenada por lo que retiró de flor seca, y
    # después por entregas. El DNI entero es dato de salud: la pantalla lo saca.
    def pacientes(lineas)
      lineas.group_by { |l| l.dispensacion.paciente_id }.map do |_, ls|
        p = ls.first.dispensacion.paciente
        unidades = por_unidad(ls)
        {
          paciente:      p&.nombre_completo,
          dni:           p&.dni_normalizado.to_s,
          dni_ultimos_3: p&.dni_normalizado.to_s.last(3),
          entregas:      ls.map(&:dispensacion).uniq.size,
          flor_seca_g:   ls.select { |l| l.forma == 'flor_seca' }.sum(&:cantidad).round(2).to_f,
          por_unidad:    unidades.map { |u, c| { unidad: u, cantidad: c } },
          otros:         otros(ls),
          geneticas:     ls.map(&:genetica).uniq,
          formas:        ls.map(&:forma).uniq,
          ultima_fecha:  ls.map { |l| l.dispensacion.fecha_dispensacion }.compact.max,
        }
      end.sort_by { |r| [-r[:flor_seca_g], -r[:entregas], r[:paciente].to_s] }
    end

    # ── 4. Por dónde ─────────────────────────────────────────────────────────

    # Mostrador de cada sede, o envío a domicilio. Un envío que todavía no llegó (en viaje, fallido,
    # pendiente) cuenta como salida —el producto salió del depósito— y la fila dice cuántos.
    def canales(lineas)
      envio, mostrador = lineas.partition { |l| l.dispensacion.con_envio }
      filas = mostrador.group_by { |l| l.dispensacion.sede&.nombre || 'Sin sede' }
                       .sort_by { |_, ls| -ls.map(&:dispensacion).uniq.size }
                       .map { |sede, ls| fila_canal("Mostrador · #{sede}", ls) }
      if envio.any?
        en_calle = envio.map(&:dispensacion).uniq.count { |d| d.estado_envio != 'entregado' }
        filas << fila_canal('Envío a domicilio', envio).merge(sin_llegar: en_calle)
      end
      filas
    end

    def fila_canal(nombre, ls)
      disps = ls.map(&:dispensacion).uniq
      { canal: nombre, entregas: disps.size, pacientes: disps.map(&:paciente_id).uniq.size,
        flor_seca_g: ls.select { |l| l.forma == 'flor_seca' }.sum(&:cantidad).round(2).to_f,
        por_unidad: por_unidad(ls).map { |u, c| { unidad: u, cantidad: c } },
        otros: otros(ls) }
    end

    # Lo que no es flor seca, cada cosa en su forma y su unidad: «10 g de hash · 6 prerolls». Un
    # hash en gramos NO se mezcla con la flor en la misma celda.
    def otros(ls)
      ls.reject { |l| l.forma == 'flor_seca' }.group_by { |l| [l.forma, l.unidad] }.map do |(forma, unidad), gs|
        { forma: forma, unidad: unidad, cantidad: gs.sum(&:cantidad).round(2).to_f }
      end
    end
  end
end
