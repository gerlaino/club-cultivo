module Analitica
  # ¿QUÉ GENÉTICA RINDE MEJOR? Sobre los lotes cerrados del universo, una fila por genética con el
  # número que manda —g/planta, ponderado— y lo que lo explica: cuánto prendió, cuánto se perdió en
  # el ciclo y cuánto tardó. Sin «objetivo» ni «desvío»: eso es «Qué dice la genética», en Plan vs.
  # real. Sin «lotes recientes»: era una lista, no un análisis.
  class Geneticas
    def initialize(universo)
      @u = universo
    end

    def call
      filas = @u.lotes.group_by(&:genetica_id).filter_map do |gid, ls|
        g = ls.first.genetica
        next if g.nil?

        pl      = ls.map { |l| @u.plantas[l.id] }
        gramos  = ls.sum { |l| l.rendimiento_real_g.to_f }
        cosech  = pl.sum { |p| p[:cosechadas] }
        total   = pl.sum { |p| p[:total] }
        noprend = pl.sum { |p| p[:no_prendio] }
        descart = pl.sum { |p| p[:descartadas] }
        prendieron = total - noprend
        totales = ls.filter_map { |l| @u.fases[l.id]['total'] }
        {
          genetica_id:   gid,
          nombre:        g.nombre,
          automatica:    g.automatica,
          lotes:         ls.size,
          suficientes:   @u.suficientes?(ls.size),
          plantas:       cosech,
          gramos:        gramos.round(1),
          g_por_planta:  cosech.positive? ? (gramos / cosech).round(1) : nil,
          # Prendió: de todas las que arrancaron, cuántas enraizaron. Se perdió en el ciclo: de las
          # que prendieron, cuántas se descartaron después (plaga, macho, rotura…).
          prendio_pct:   total.positive? ? ((prendieron * 100.0) / total).round(1) : nil,
          perdida_pct:   prendieron.positive? ? (((descart - noprend) * 100.0) / prendieron).round(1) : nil,
          ciclo_dias:    totales.any? ? (totales.sum / totales.size).round(0) : nil,
        }
      end
      filas.sort_by { |f| [f[:suficientes] ? 0 : 1, -(f[:g_por_planta] || 0)] }
    end
  end
end
