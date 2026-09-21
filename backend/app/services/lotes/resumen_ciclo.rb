# «Cómo salió»: el resumen de un ciclo cuando termina (20-sep-2026).
#
# Hasta acá, un lote terminaba y no pasaba nada: la tarjeta desaparecía del inicio y los
# números quedaban repartidos entre la ficha, la analítica y los gastos. Para el que cultiva en
# casa el cierre es EL momento —ahí compara con el ciclo anterior y decide qué cambiar—, así
# que se juntan en un solo lugar. No calcula nada nuevo: fases y plantas salen de
# `Analitica::Universo` (el mismo cálculo que la solapa Fases), el costo de `CostoLote`, la
# nutrición de los registros de riego y las fotos de la galería.
#
# `anterior`: el promedio de los ciclos cerrados de la MISMA genética, sin éste, para decir
# «+12 % que tu ciclo anterior». nil si no hay contra qué comparar; la pantalla no inventa.
module Lotes
  class ResumenCiclo
    CERRADOS = %w[curado finalizado].freeze

    # `con_costo`: la plata es de administración (misma regla que la tarjeta P&L del lote); un
    # cultivador o un manicura ven el ciclo sin pesos. Lo decide el controller por el rol.
    def initialize(lote, url_helper: nil, con_costo: true)
      @lote = lote
      @club = lote.club
      @url  = url_helper
      @con_costo = con_costo
    end

    def call
      u      = Analitica::Universo.new(club: @club, lotes: [@lote])
      fases  = u.fases[@lote.id] || {}
      pl     = u.plantas[@lote.id] || {}
      gramos = @lote.rendimiento_real_g.to_f
      cosechadas = pl[:cosechadas].to_i
      costo  = @lote.costo_lote

      {
        cerrado:    CERRADOS.include?(@lote.estado),
        estado:     @lote.estado,
        # Automática: la tarjeta muestra el ciclo entero, no vege/flora por separado.
        automatica: @lote.automatica?,
        gramos:     gramos.positive? ? gramos.round(1) : nil,
        plantas:    { total: pl[:total].to_i, cosechadas: cosechadas, no_prendieron: pl[:no_prendio].to_i,
                      descartadas: pl[:descartadas].to_i },
        g_por_planta: (gramos.positive? && cosechadas.positive?) ? (gramos / cosechadas).round(1) : nil,
        dias:       fases.slice('enraizado', 'vegetativo', 'floracion', 'cosecha', 'en_manicura', 'total'),
        costo:      @con_costo && costo && costo.costo_total.to_f.positive? ? {
          total:     costo.costo_total.to_f.round(2),
          por_gramo: costo.costo_por_gramo&.to_f&.round(2),
          nutricion: costo_nutricion,
        } : nil,
        registros:  registros,
        fotos:      fotos,
        anterior:   anterior,
      }
    end

    private

    # Lo que se gastó en nutrientes según los riegos con receta o productos (copia congelada en
    # cada registro: `nutricion.costo_ars`).
    def costo_nutricion
      @lote.registros_ambientales.where.not(nutricion: nil).sum { |r| r.nutricion.to_h['costo_ars'].to_f }.round(2)
    end

    # `tareas_realizadas` es jsonb: `@>` pregunta si la lista contiene «riego».
    def registros
      regs = @lote.registros_ambientales
      { total: regs.count, riegos: regs.where('tareas_realizadas @> ?', ['riego'].to_json).count }
    end

    # La primera y la última foto: ver de dónde salió y a dónde llegó.
    def fotos
      todas = @lote.lote_fotos.cronologicas.includes(imagen_attachment: :blob)
      primera, ultima = todas.first, todas.last
      { total: todas.size, primera: foto(primera), ultima: (ultima && ultima != primera) ? foto(ultima) : nil }
    end

    def foto(f)
      return nil unless f&.imagen&.attached?
      { id: f.id, dia: f.dia_de_vida, fase: f.fase, url: @url ? @url.call(f.imagen) : nil }
    end

    # Los ciclos cerrados anteriores de la misma genética, promediados como lo hace la analítica
    # (suma ÷ suma, nunca promedio de promedios). Sin ninguno de la misma genética se compara
    # contra TODOS los cerrados (`misma_genetica: false`, y la tarjeta lo dice): el primer ciclo
    # de una variedad nueva tiene igual contra qué mirarse.
    def anterior
      cerrados = @club.lotes.where(estado: CERRADOS).where('rendimiento_real_g > 0').where.not(id: @lote.id)
      otros    = @lote.genetica_id.present? ? cerrados.where(genetica_id: @lote.genetica_id) : cerrados.none
      misma    = otros.any?
      otros    = cerrados unless misma
      return nil if otros.none?

      u  = Analitica::Universo.new(club: @club, lotes: otros)
      gramos = u.lotes.sum { |l| l.rendimiento_real_g.to_f }
      cosech = u.lotes.sum { |l| u.plantas.dig(l.id, :cosechadas).to_i }
      totales = u.lotes.filter_map { |l| u.fases.dig(l.id, 'total') }
      costeados = @con_costo ? u.lotes.select { |l| l.costo_lote&.costo_total.to_f.positive? && l.rendimiento_real_g.to_f.positive? } : []
      {
        lotes:        u.lotes.size,
        misma_genetica: misma,
        g_por_planta: cosech.positive? ? (gramos / cosech).round(1) : nil,
        dias_total:   totales.any? ? (totales.sum / totales.size).round(1) : nil,
        costo_por_gramo: costeados.any? ? (costeados.sum { |l| l.costo_lote.costo_total.to_f } / costeados.sum { |l| l.rendimiento_real_g.to_f }).round(2) : nil,
      }
    end
  end
end
