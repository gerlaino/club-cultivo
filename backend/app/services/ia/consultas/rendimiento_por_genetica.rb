module Ia
  module Consultas
    # Qué rinde cada genética DE VERDAD en las salas de esta organización.
    #
    # No es `geneticas.rendimiento`, que es el número declarado por el criador y no sirve para
    # decidir: sirve el que sale de los lotes propios.
    #
    # Devuelve dos cosas y la segunda importa tanto como la primera:
    #   - gramos por planta, que es lo que todo el mundo mira
    #   - **gramos por planta por semana de ciclo**, que es lo que casi nadie mira y a veces da
    #     vuelta el resultado: el recurso escaso de un club no es la semilla, es la SALA. Una
    #     genética que rinde 18% menos por cosecha puede producir más al año si libera la sala
    #     tres semanas antes.
    class RendimientoPorGenetica < Base
      # Con uno o dos ciclos no se compara nada: es una anécdota, y la diferencia entre dos
      # genéticas queda tapada por la variación entre ciclos de la misma. Tres es el mínimo para
      # que la comparación signifique algo — es un piso elegido a mano, no derivado: cuando haya
      # datos conviene calibrarlo mirando si la variación ENTRE genéticas supera la variación
      # DENTRO de cada una.
      MINIMO_LOTES = 3

      # Para COMPARAR hacen falta al menos dos que lleguen al mínimo. Con una sola no hay "mejor":
      # el modelo la presentaría como la ganadora de una carrera que corrió sola. Salió mirando
      # datos reales — los tres clubes tenían exactamente UNA genética con 3 lotes, y la consulta
      # daba "suficiente" igual.
      MINIMO_COMPARABLES = 2

      # Cuántos lotes tienen que aportar fecha real de cosecha para publicar el ciclo. Con uno no
      # es el ciclo de la genética, es el de ese lote — y se leía como si resumiera todos. En los
      # datos reales sólo 4 de 10 lotes cosechados tenían la fecha cargada, así que esto pasa
      # seguido y en silencio.
      MINIMO_PARA_CICLO = 2

      def resolver(**)
        por_genetica = agrupar

        comparables, escasas = por_genetica.partition { |g| g[:lotes] >= MINIMO_LOTES }

        return sin_datos(escasas) if comparables.empty?
        return sin_con_que_comparar(comparables, escasas) if comparables.size < MINIMO_COMPARABLES

        suficiente(
          minimo_por_genetica: MINIMO_LOTES,
          geneticas:           comparables.sort_by { |g| -(g[:g_por_planta] || 0) },
          # Las que no llegan viajan igual, para que la respuesta pueda decir "de Amnesia
          # todavía no puedo" en vez de callarlas y parecer que no existen.
          todavia_sin_datos:   escasas.map { |g| g.slice(:genetica, :lotes) }
        )
      end

      private

      # Hay UNA que llega al mínimo. No alcanza para contestar "cuál rinde mejor", pero lo que se
      # sabe de esa sí sirve: se manda igual para poder decir "de Critical sé esto, pero no tengo
      # con qué compararla" en vez de callarla.
      def sin_con_que_comparar(comparables, escasas)
        unica = comparables.first
        insuficiente(
          "hay una sola genética con al menos #{MINIMO_LOTES} lotes cosechados (#{unica[:genetica]}), " \
          "así que todavía no se puede comparar: hacen falta #{MINIMO_COMPARABLES}",
          disponible: {
            unica_con_datos:   unica,
            todavia_sin_datos: escasas.map { |g| g.slice(:genetica, :lotes) },
          }
        )
      end

      def sin_datos(escasas)
        mejor = escasas.max_by { |g| g[:lotes] }
        detalle = if mejor
                    "la que más tiene es #{mejor[:genetica]} con #{mejor[:lotes]}"
                  else
                    'todavía no hay lotes cosechados con rendimiento cargado'
                  end

        insuficiente(
          "hacen falta al menos #{MINIMO_LOTES} lotes cosechados de una misma genética para " \
          "poder compararlas; #{detalle}",
          disponible: escasas.map { |g| g.slice(:genetica, :lotes) }
        )
      end

      # Un lote cuenta cuando tiene rendimiento cargado: eso es lo que dice que se cosechó y se
      # pesó, mejor que mirar el estado (un lote puede estar en `curado` sin pesada aprobada).
      def agrupar
        club.lotes.where.not(rendimiento_real_g: nil)
            .where.not(genetica_id: nil)
            .includes(:genetica)
            .group_by(&:genetica_id)
            .filter_map { |_id, lotes| fila(lotes) }
      end

      def fila(lotes)
        nombre = lotes.first.genetica&.nombre
        return nil if nombre.blank?

        plantas = lotes.sum { |l| (l.plants_count_cosechadas || l.plants_count).to_i }
        gramos  = lotes.sum { |l| l.rendimiento_real_g.to_f }
        duraciones = duraciones_reales(lotes)
        semanas    = duraciones.any? ? (duraciones.sum / duraciones.size).round(1) : nil

        g_planta = plantas.positive? ? (gramos / plantas).round(1) : nil
        # Con un solo lote no es el ciclo de la genética, es el de ese lote. Se publica recién con
        # dos, y siempre acompañado de cuántos lo sostienen.
        publicable = duraciones.size >= MINIMO_PARA_CICLO

        {
          genetica:        nombre,
          lotes:           lotes.size,
          gramos_totales:  gramos.round,
          g_por_planta:    g_planta,
          # Sin esto, "37,5 g por semana de sala sobre 4 lotes" podía salir de UN lote: el
          # rendimiento venía de cuatro y las semanas de uno, y la frase no lo distinguía.
          lotes_con_ciclo: duraciones.size,
          semanas_ciclo:   publicable ? semanas : nil,
          # El número que ordena la decisión de qué plantar el ciclo que viene.
          g_por_planta_por_semana: (publicable && g_planta && semanas&.positive? ? (g_planta / semanas).round(1) : nil),
        }
      end

      # Ciclo REAL: del arranque del lote a la última planta cosechada. Si un lote no tiene esas
      # fechas queda afuera del promedio en vez de rellenarse con el objetivo — mezclar plan y
      # real en un mismo número es exactamente lo que hace que después nadie confíe en el dato.
      def duraciones_reales(lotes)
        lotes.filter_map do |lote|
          fin = lote.plants.maximum(:fecha_cosecha)
          next if fin.blank? || lote.start_date.blank?

          dias = (fin.to_date - lote.start_date.to_date).to_i
          dias.positive? ? dias / 7.0 : nil
        end
      end
    end
  end
end
