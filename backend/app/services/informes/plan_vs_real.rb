module Informes
  # PLAN VS. REAL es del admin: es el informe con el que aprende a planificar. Tres bloques:
  #
  #   1. Cómo salió — los lotes cosechados en el período, contra su plan: gramos, g/planta y DÍAS
  #      por etapa. El plan de un cultivo es tiempo además de gramos: un lote que rindió lo
  #      planeado en 20 días más no cumplió el plan, y el informe viejo no miraba los días.
  #   2. Cómo viene — los lotes en cultivo, contra su plan hasta hoy.
  #   3. Qué dice la genética — lo que rinde de verdad en esta organización contra su ficha, que
  #      es de donde el lote hereda el objetivo. Es lo que permite corregir el plan de la próxima
  #      vez en lugar de repetir el error.
  #
  # El desvío se PONDERA (suma de reales contra suma de planeados): el promedio de porcentajes
  # pesaba igual un lote de 3 plantas que uno de 40. «Cumplió» es gramos dentro del ±10 % y
  # floración dentro de ±7 días (decisión de Germán, sep-2026): es la definición del informe.
  class PlanVsReal
    TOLERANCIA_GRAMOS_PCT = 10
    TOLERANCIA_DIAS       = 7

    def initialize(club:, desde:, hasta:)
      @club  = club
      @desde = desde
      @hasta = hasta
    end

    def call
      {
        salio:     salio,
        viene:     viene,
        geneticas: geneticas,
        tolerancia: { gramos_pct: TOLERANCIA_GRAMOS_PCT, dias: TOLERANCIA_DIAS },
      }
    end

    private

    # Fecha de entrada a cada estado, por lote: la PRIMERA vez que entró.
    def entradas(lotes_ids)
      LoteEvento.where(lote_id: lotes_ids, tipo: 'cambio_estado')
                .group(:lote_id, :estado_nuevo).minimum(:registrado_en)
                .each_with_object(Hash.new { |h, k| h[k] = {} }) { |((lid, est), f), h| h[lid][est] = f&.to_date }
    end

    # Cuántos días llevó cada etapa, de la entrada a la siguiente. Nil si no hay fechas.
    def dias_reales(ent)
      veg  = ent['vegetativo']
      flo  = ent['floracion']
      cos  = ent['cosecha'] || ent['en_manicura'] || ent['curado'] || ent['finalizado']
      { vegetativo: (veg && flo ? (flo - veg).to_i : nil), floracion: (flo && cos ? (cos - flo).to_i : nil) }
    end

    # ── 1. Cómo salió ────────────────────────────────────────────────────────

    def salio
      lotes = @club.lotes.includes(:genetica).to_a
      ents  = entradas(lotes.map(&:id))
      cosechados = lotes.select do |l|
        f = ents[l.id]['cosecha'] || ents[l.id]['en_manicura'] || ents[l.id]['curado'] || ents[l.id]['finalizado']
        f && f >= @desde.to_date && f <= @hasta.to_date
      end

      filas = cosechados.map { |l| fila_salio(l, ents[l.id]) }
      con_g   = filas.select { |f| f[:g_plan].to_f.positive? && f[:g_real].to_f.positive? }
      con_flo = filas.select { |f| f[:flora_plan] && f[:flora_real] }
      con_veg = filas.select { |f| f[:vege_plan] && f[:vege_real] }
      g_plan = con_g.sum { |f| f[:g_plan] }.round(1)
      g_real = con_g.sum { |f| f[:g_real] }.round(1)
      pl_plan = con_g.sum { |f| f[:plantas_plan].to_i }
      pl_real = con_g.sum { |f| f[:plantas].to_i }

      {
        lotes:            filas.sort_by { |f| f[:fecha_cosecha] || Date.new(1970) }.reverse,
        total:            filas.size,
        gramos:           { plan: g_plan, real: g_real, desvio_pct: desvio(g_real, g_plan), lotes: con_g.size },
        gramos_por_planta: {
          plan: pl_plan.positive? ? (g_plan / pl_plan).round(1) : nil,
          real: pl_real.positive? ? (g_real / pl_real).round(1) : nil,
        },
        floracion: { plan: promedio(con_flo.map { |f| f[:flora_plan] }), real: promedio(con_flo.map { |f| f[:flora_real] }), lotes: con_flo.size },
        vegetativo: { plan: promedio(con_veg.map { |f| f[:vege_plan] }), real: promedio(con_veg.map { |f| f[:vege_real] }), lotes: con_veg.size },
        cumplieron: filas.count { |f| f[:cumplio] == true },
        evaluables: filas.count { |f| !f[:cumplio].nil? },
      }
    end

    def fila_salio(l, ent)
      dias = dias_reales(ent)
      g_plan = l.rendimiento_objetivo_g&.to_f
      g_real = l.rendimiento_real_g&.to_f
      plantas = l.plants_count_cosechadas || l.plants_count
      desv_g = desvio(g_real, g_plan)
      desv_f = l.dias_floracion_objetivo && dias[:floracion] ? dias[:floracion] - l.dias_floracion_objetivo : nil
      veredicto = []
      veredicto << (desv_g.abs <= TOLERANCIA_GRAMOS_PCT ? 'gramos ✓' : "#{desv_g.positive? ? '+' : ''}#{desv_g} % gramos") if desv_g
      veredicto << (desv_f.abs <= TOLERANCIA_DIAS ? 'floración ✓' : "floración #{desv_f.positive? ? '+' : ''}#{desv_f} días") if desv_f
      cumplio = if desv_g.nil? && desv_f.nil?
                  nil
                else
                  (desv_g.nil? || desv_g.abs <= TOLERANCIA_GRAMOS_PCT) && (desv_f.nil? || desv_f.abs <= TOLERANCIA_DIAS)
                end
      {
        id: l.id, codigo: l.codigo, genetica: l.genetica&.nombre, estado: l.estado,
        fecha_cosecha: ent['cosecha'] || ent['en_manicura'] || ent['curado'],
        plantas: plantas, plantas_plan: l.plants_count_objetivo,
        g_plan: g_plan, g_real: g_real, desvio_g_pct: desv_g,
        g_por_planta: g_real && plantas.to_i.positive? ? (g_real / plantas).round(1) : nil,
        vege_plan: l.dias_vegetativo_objetivo, vege_real: dias[:vegetativo],
        flora_plan: l.dias_floracion_objetivo, flora_real: dias[:floracion], desvio_flora_dias: desv_f,
        veredicto: veredicto.join(' · ').presence || 'sin plan para comparar',
        cumplio: cumplio,
      }
    end

    # ── 2. Cómo viene ────────────────────────────────────────────────────────

    def viene
      lotes = @club.lotes.where(estado: Lote::CULTIVO_ESTADOS).includes(:genetica, :sala).to_a
      ents  = entradas(lotes.map(&:id))
      hoy   = Time.zone.today
      lotes.map do |l|
        plan = l.estado == 'floracion' ? l.dias_floracion_objetivo : (l.estado == 'vegetativo' ? l.dias_vegetativo_objetivo : nil)
        llevo = l.dias_en_estado
        cosecha = l.fecha_cosecha_estimada || (ents[l.id]['floracion'] && l.dias_floracion_objetivo && ents[l.id]['floracion'] + l.dias_floracion_objetivo.days)
        pasado = plan && llevo ? llevo - plan : nil
        como = if pasado.nil? then 'sin plan para comparar'
               elsif pasado > TOLERANCIA_DIAS then "#{pasado} días pasado del plan y sigue en #{Lote::ESTADOS.include?(l.estado) ? l.estado : ''}"
               elsif pasado > 0 then "#{pasado} días sobre el plan"
               else 'en fecha'
               end
        { id: l.id, codigo: l.codigo, genetica: l.genetica&.nombre, sala: l.sala&.nombre, estado: l.estado,
          dias_plan: plan, dias_hoy: llevo, cosecha_planeada: cosecha, pasado_dias: pasado, como_viene: como,
          plantas: l.plants_count }
      end.sort_by { |f| [-(f[:pasado_dias] || -999), f[:codigo]] }
    end

    # ── 3. Qué dice la genética ──────────────────────────────────────────────

    # Sobre TODOS los lotes cerrados de la organización (no sólo los del período): la ficha se
    # compara contra la historia entera, que es lo que la corrige.
    def geneticas
      lotes = @club.lotes.where('rendimiento_real_g > 0').where.not(genetica_id: nil).includes(:genetica).to_a
      ents  = entradas(lotes.map(&:id))
      lotes.group_by(&:genetica).filter_map do |g, ls|
        next if g.nil?

        con_pl = ls.select { |l| l.plants_count_cosechadas.to_i.positive? }
        gpp_real = con_pl.any? ? (con_pl.sum { |l| l.rendimiento_real_g.to_f } / con_pl.sum { |l| l.plants_count_cosechadas }).round(1) : nil
        flos = ls.filter_map { |l| dias_reales(ents[l.id])[:floracion] }
        flo_real = promedio(flos)
        frase = []
        if gpp_real && g.rendimiento.to_f.positive?
          d = desvio(gpp_real, g.rendimiento.to_f)
          frase << (d.abs <= TOLERANCIA_GRAMOS_PCT ? 'rinde lo que dice su ficha' : "rinde #{d.abs} % #{d.negative? ? 'menos' : 'más'} que su ficha")
        end
        if flo_real && g.tiempo_floracion.to_i.positive?
          d = flo_real - g.tiempo_floracion
          frase << (d.abs <= TOLERANCIA_DIAS ? 'en el tiempo de la ficha' : "tarda #{d.abs} días #{d.positive? ? 'más' : 'menos'}")
        end
        { genetica: g.nombre, lotes: ls.size,
          g_por_planta_ficha: g.rendimiento, g_por_planta_real: gpp_real,
          floracion_ficha: g.tiempo_floracion, floracion_real: flo_real,
          frase: frase.join(' · ').presence || 'sin ficha para comparar' }
      end.sort_by { |x| -x[:lotes] }
    end

    def desvio(real, plan)
      return nil unless real.to_f.positive? && plan.to_f.positive?

      (((real.to_f - plan.to_f) / plan.to_f) * 100).round(1)
    end

    def promedio(xs)
      xs = xs.compact
      xs.any? ? (xs.sum.to_f / xs.size).round : nil
    end
  end
end
