module Ia
  module Consultas
    # Cuánto cuesta el gramo, por genética.
    #
    # Es el número con el que un club fija el aporte, y hoy se calcula a ojo. Sale de
    # `costo_lotes`, que ya guarda insumos, energía, mano de obra y `costo_por_gramo` calculado.
    #
    # DOS CUIDADOS, y el segundo es específico de acá:
    #
    #   1. Sólo cuentan los lotes CON COSTO CARGADO, y se dice cuántos son de cuántos. Promediar
    #      cuatro lotes sin aclarar que hay doce es peor que no contestar: suena igual de seguro.
    #
    #   2. **La inflación rompe la comparación entre períodos.** `costo_por_gramo` está en pesos:
    #      comparar un lote de marzo contra uno de agosto compara meses, no genéticas, y el ruido
    #      se come tranquilamente la diferencia real. Por eso se acota a una VENTANA y se informa
    #      cuál — indexar sería más exacto pero necesita un índice que no tenemos.
    class CostoPorGenetica < Base
      MINIMO_LOTES  = 3
      # Con más de esto, la inflación pesa más que la diferencia entre genéticas.
      VENTANA_MESES = 6

      def resolver(**)
        desde = VENTANA_MESES.months.ago.to_date
        filas = agrupar(desde)

        comparables, escasas = filas.partition { |f| f[:lotes_con_costo] >= MINIMO_LOTES }
        return sin_datos(escasas, desde) if comparables.empty?

        suficiente(
          desde:               desde,
          ventana_meses:       VENTANA_MESES,
          minimo_por_genetica: MINIMO_LOTES,
          moneda:              'ARS',
          geneticas:           comparables.sort_by { |f| f[:costo_por_gramo] },
          todavia_sin_datos:   escasas.map { |f| f.slice(:genetica, :lotes_cosechados, :lotes_con_costo) },
          nota: "Sólo lotes de los últimos #{VENTANA_MESES} meses: los costos están en pesos y " \
                'comparar contra un lote más viejo compara inflación, no genéticas.'
        )
      end

      private

      def sin_datos(escasas, desde)
        mejor = escasas.max_by { |f| f[:lotes_con_costo] }
        detalle = if mejor && mejor[:lotes_con_costo].positive?
                    "la que más tiene es #{mejor[:genetica]} con #{mejor[:lotes_con_costo]} " \
                    "de #{mejor[:lotes_cosechados]} lotes"
                  else
                    'todavía no hay lotes con el costo cargado en ese período'
                  end

        insuficiente(
          "hacen falta al menos #{MINIMO_LOTES} lotes con costo cargado de una misma genética, " \
          "cosechados desde #{desde.strftime('%m/%Y')}; #{detalle}",
          disponible: escasas.map { |f| f.slice(:genetica, :lotes_cosechados, :lotes_con_costo) }
        )
      end

      def agrupar(desde)
        club.lotes.where.not(genetica_id: nil).where('start_date >= ?', desde)
            .includes(:genetica, :costo_lote)
            .group_by(&:genetica_id)
            .filter_map { |_id, lotes| fila(lotes) }
      end

      def fila(lotes)
        nombre = lotes.first.genetica&.nombre
        return nil if nombre.blank?

        con_costo = lotes.select { |l| l.costo_lote&.costo_por_gramo.present? }
        cosechados = lotes.count { |l| l.rendimiento_real_g.present? }

        base = { genetica: nombre, lotes_cosechados: cosechados, lotes_con_costo: con_costo.size }
        return base.merge(costo_por_gramo: nil) if con_costo.empty?

        costos = con_costo.map { |l| l.costo_lote.costo_por_gramo.to_f }

        base.merge(
          costo_por_gramo: (costos.sum / costos.size).round(2),
          # El rango importa tanto como el promedio: si va de $80 a $400, el promedio no describe
          # nada y lo que hay que mirar es por qué varían tanto entre sí.
          minimo:          costos.min.round(2),
          maximo:          costos.max.round(2)
        )
      end
    end
  end
end
