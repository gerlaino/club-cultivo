module Analitica
  # ¿EN QUÉ SALA, CON QUÉ MÉTODO, CON QUÉ AMBIENTE RINDE MEJOR? g/planta cortado por sala de
  # floración, método de cultivo o luz — y, para cada corte, el ambiente que vivió la floración:
  # lecturas de la SALA (sensores incluidos) entre la entrada a floración y el corte. Reemplaza a
  # «Comparativa» (tarjetas sin pregunta) y a «Ambiente» (regresiones sobre el promedio del ciclo
  # entero, y sólo con lecturas cargadas a mano sobre el lote).
  #
  # Hoy los sensores no están conectados (Germán, 13-sep): el bloque queda preparado y dice «sin
  # lecturas» hasta que lleguen.
  class DondeYComo
    # `receta`: con qué receta de nutrientes se regó más veces cada lote (20-sep-2026). Es la
    # pregunta que hace un cultivador: «¿con qué receta rindió más?».
    CORTES   = %w[sala metodo luz receta].freeze
    AMBIENTE = %w[temperatura humedad vpd].freeze

    def initialize(universo, corte: 'sala')
      @u     = universo
      @corte = CORTES.include?(corte.to_s) ? corte.to_s : 'sala'
    end

    def call
      grupos = @u.lotes.group_by { |l| clave(l) }
      filas = grupos.map do |clave, ls|
        pl     = ls.map { |l| @u.plantas[l.id] }
        gramos = ls.sum { |l| l.rendimiento_real_g.to_f }
        cosech = pl.sum { |p| p[:cosechadas] }
        flo    = ls.filter_map { |l| @u.fases[l.id]['floracion'] }
        amb    = ambiente_de(ls)
        {
          clave:        clave,
          nombre:       nombre(clave, ls),
          lotes:        ls.size,
          suficientes:  @u.suficientes?(ls.size),
          plantas:      cosech,
          gramos:       gramos.round(1),
          g_por_planta: cosech.positive? ? (gramos / cosech).round(1) : nil,
          floracion_dias: flo.any? ? (flo.sum / flo.size).round(0) : nil,
          ambiente:     amb,
          # Lo gastado en nutrientes con receta, por planta cosechada.
          nutrientes_por_planta: cosech.positive? ? (ls.sum { |l| costo_nutrientes(l) } / cosech).round(0) : nil,
        }
      end
      mejor = filas.select { |f| f[:suficientes] && f[:g_por_planta] }.max_by { |f| f[:g_por_planta] }
      filas.each do |f|
        f[:mejor] = mejor && f[:clave] == mejor[:clave]
        f[:contra_mejor_pct] = mejor && f[:g_por_planta] && mejor[:g_por_planta].positive? && !f[:mejor] ?
                                 (((f[:g_por_planta] - mejor[:g_por_planta]) / mejor[:g_por_planta]) * 100).round(0) : nil
      end
      { corte: @corte, filas: filas.sort_by { |f| [f[:suficientes] ? 0 : 1, -(f[:g_por_planta] || 0)] },
        con_lecturas: filas.any? { |f| f[:ambiente].present? } }
    end

    private

    def clave(l)
      case @corte
      when 'sala'   then @u.floracion[l.id][:sala_id]
      when 'metodo' then l.grow_type.presence
      when 'luz'    then l.light_type.presence
      when 'receta' then receta_principal(l)&.first
      end
    end

    # La receta con la que más veces se regó el lote: [id, nombre]. Nil si nunca aplicó una.
    def receta_principal(l)
      @recetas ||= {}
      return @recetas[l.id] if @recetas.key?(l.id)
      conteo = RegistroAmbiental.where(lote_id: l.id).where.not(receta_id: nil).group(:receta_id).count
      @recetas[l.id] = if conteo.empty? then nil
                       else id = conteo.max_by { |_, c| c }.first; [id, Receta.unscoped.find_by(id: id)&.nombre]
                       end
    end

    def costo_nutrientes(l)
      @costos ||= {}
      @costos[l.id] ||= RegistroAmbiental.where(lote_id: l.id).where.not(nutricion: nil).pluck(:nutricion).sum { |n| n.to_h['costo_ars'].to_f }
    end

    def nombre(clave, ls)
      return 'Sin dato' if clave.nil?

      case @corte
      when 'sala'   then @u.floracion[ls.first.id][:sala]
      when 'receta' then receta_principal(ls.first)&.last || 'Sin receta'
      else clave.to_s.tr('_', ' ').capitalize
      end
    end

    # Promedio, por lote, de las lecturas de su sala durante SU floración; y el promedio de esos
    # lotes. nil si ninguno tiene lecturas: sin dato no es un cero.
    def ambiente_de(ls)
      por_lote = ls.filter_map do |l|
        f = @u.floracion[l.id]
        next if f[:sala_id].nil? || f[:desde].nil?

        lecturas = LecturaAmbiental.where(sala_id: f[:sala_id], tipo: AMBIENTE)
                                   .where(medido_at: f[:desde]..(f[:hasta] || Time.current))
                                   .group(:tipo).average(:valor)
        next if lecturas.empty?

        lecturas.transform_values(&:to_f)
      end
      return nil if por_lote.empty?

      AMBIENTE.to_h do |tipo|
        vals = por_lote.filter_map { |h| h[tipo] }
        [tipo, vals.any? ? (vals.sum / vals.size).round(tipo == 'vpd' ? 2 : 1) : nil]
      end.merge('lotes_con_lecturas' => por_lote.size)
    end
  end
end
