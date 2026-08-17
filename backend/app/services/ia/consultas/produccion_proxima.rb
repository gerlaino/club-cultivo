module Ia
  module Consultas
    # ¿Voy a tener producto el mes que viene?
    #
    # Es la pregunta que desvela al admin de un club: no compite por margen, compite contra
    # quedarse sin producto para sus pacientes. Y es la única de las consultas que NO lleva
    # umbral de historia, porque no mira el pasado: mira lo que hay hoy en las salas.
    #
    # El estimado sale de una de dos fuentes y SIEMPRE dice cuál. Un número sin origen no se
    # puede discutir, y acá el origen cambia cuánto vale: el objetivo lo cargó una persona a ojo,
    # el histórico salió de cosechas reales.
    class ProduccionProxima < Base
      EN_CURSO = %w[floracion cosecha secado curado].freeze

      def resolver(dias: 60, **)
        lotes = club.lotes.where(estado: EN_CURSO).includes(:genetica, :sala)
        return insuficiente('no hay lotes en floración ni en post-cosecha ahora mismo') if lotes.empty?

        filas = lotes.map { |lote| fila(lote) }

        suficiente(
          horizonte_dias:   dias,
          lotes:            filas.sort_by { |f| f[:dias_para_cosecha] || 9_999 },
          gramos_estimados: filas.sum { |f| f[:gramos_estimados].to_i },
          # Sin esto el total parece un pronóstico firme. Con esto se lee como lo que es.
          advertencia:      advertencia(filas)
        )
      end

      private

      def fila(lote)
        estimado, origen = estimar(lote)

        {
          lote:               lote.codigo,
          genetica:           lote.genetica&.nombre,
          sala:               lote.sala&.nombre,
          estado:             lote.estado,
          plantas:            (lote.plants_count_cosechadas || lote.plants_count).to_i,
          dias_para_cosecha:  dias_para_cosecha(lote),
          gramos_estimados:   estimado,
          estimado_segun:     origen,
        }
      end

      # Ya cosechado y pesado: deja de ser estimación.
      def estimar(lote)
        return [lote.rendimiento_real_g.to_i, 'pesado real'] if lote.rendimiento_real_g.present?
        return [lote.rendimiento_objetivo_g.to_i, 'objetivo cargado'] if lote.rendimiento_objetivo_g.present?

        historico = historico_por_planta(lote.genetica_id)
        plantas   = (lote.plants_count_cosechadas || lote.plants_count).to_i
        return [(historico * plantas).round, 'histórico de la genética'] if historico && plantas.positive?

        [nil, 'sin base para estimar']
      end

      # Gramos por planta que dio ESA genética en esta organización. Nil si nunca se cosechó:
      # antes que inventar un número, se dice que no hay con qué.
      def historico_por_planta(genetica_id)
        return nil if genetica_id.blank?

        @historico ||= {}
        @historico.fetch(genetica_id) do
          cosechados = club.lotes.where(genetica_id: genetica_id).where.not(rendimiento_real_g: nil)
          plantas    = cosechados.sum { |l| (l.plants_count_cosechadas || l.plants_count).to_i }
          gramos     = cosechados.sum { |l| l.rendimiento_real_g.to_f }

          @historico[genetica_id] = plantas.positive? ? (gramos / plantas) : nil
        end
      end

      def dias_para_cosecha(lote)
        return 0 if %w[cosecha secado curado].include?(lote.estado)
        return nil if lote.fecha_cosecha_estimada.blank?

        (lote.fecha_cosecha_estimada.to_date - Time.zone.today).to_i
      end

      def advertencia(filas)
        sin_base = filas.count { |f| f[:gramos_estimados].nil? }
        sin_fecha = filas.count { |f| f[:dias_para_cosecha].nil? }
        avisos = []
        avisos << "#{sin_base} lote(s) sin base para estimar rendimiento" if sin_base.positive?
        avisos << "#{sin_fecha} lote(s) sin fecha de cosecha estimada"    if sin_fecha.positive?
        avisos.presence&.join('; ')
      end
    end
  end
end
