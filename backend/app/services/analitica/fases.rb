module Analitica
  # ¿CUÁNTO TARDA CADA FASE? Por genética, los días promedio en cada estado real del lote —de la
  # cronología, no de una fase `secado` que no existe— con el prendimiento adelante (es la primera
  # etapa del ciclo, no otra solapa) y el origen del material al lado: un esqueje y una semilla no
  # enraízan igual, así que los días de enraizado sólo se leen sabiendo contra qué compararlos.
  class Fases
    def initialize(universo)
      @u = universo
    end

    def call
      filas = @u.lotes.group_by(&:genetica_id).filter_map do |gid, ls|
        g = ls.first.genetica
        next if g.nil?

        pl   = ls.map { |l| @u.plantas[l.id] }
        tot  = pl.sum { |p| p[:total] }
        nop  = pl.sum { |p| p[:no_prendio] }
        dias = (Universo::FASES + ['total']).to_h do |fase|
          vals = ls.filter_map { |l| @u.fases[l.id][fase] }
          [fase, vals.any? ? (vals.sum / vals.size).round(0) : nil]
        end
        origenes = ls.map { |l| l.origen.presence || 'semilla' }.tally
        {
          genetica_id: gid,
          nombre:      g.nombre,
          lotes:       ls.size,
          suficientes: @u.suficientes?(ls.size),
          prendio_pct: tot.positive? ? (((tot - nop) * 100.0) / tot).round(1) : nil,
          origenes:    origenes,
          origen_label: origenes.map { |o, n| "#{n} de #{o}" }.join(' · '),
          dias:        dias,
        }
      end
      filas.sort_by { |f| [f[:suficientes] ? 0 : 1, f[:nombre]] }
    end
  end
end
