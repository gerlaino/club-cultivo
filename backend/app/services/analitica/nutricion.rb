module Analitica
  # ¿QUÉ RECIBIÓ CADA LOTE Y CÓMO RINDIÓ? (29-sep-2026). De 2 a 4 lotes lado a lado: lo que
  # recibió cada uno (`Lotes::Nutricion`, la fuente única) contra lo que dio. No reemplaza al corte
  # «receta» de Dónde y cómo (que agrupa muchos lotes por la receta que más usaron): acá se
  # comparan lotes concretos con TODO lo que recibieron.
  #
  # Lo del lote (días por fase, plantas) sale de `Universo` con los lotes fijados a mano, igual que
  # el resumen del ciclo: el mismo cálculo que el resto de la analítica. Un lote en curso entra
  # igual, sin rendimiento.
  class Nutricion
    MAXIMO = 4

    def initialize(club:, lote_ids:, con_costo: true)
      @club = club
      @ids  = Array(lote_ids).map(&:to_i).uniq.first(MAXIMO)
      @con_costo = con_costo
    end

    def call
      lotes = @club.lotes.where(id: @ids).includes(:genetica, :sala, :lote_eventos, :registros_ambientales).to_a
                   .sort_by { |l| @ids.index(l.id) }
      u = Universo.new(club: @club, lotes: lotes)
      filas = lotes.map { |l| fila(l, u) }
      {
        con_costo: @con_costo,
        lotes:     filas,
        # Las filas de la tabla: todos los productos que recibió alguno, el mismo producto de dos
        # sedes junto (nombre y unidad, el criterio de `Insumo#equivalente_en`).
        productos: filas.flat_map { |f| f[:totales][:productos] }
                        .uniq { |p| [p[:nombre].downcase, p[:unidad]] }
                        .map { |p| { clave: clave(p), nombre: p[:nombre], unidad: p[:unidad] } },
        # El eje de la curva: las semanas de fase que tuvo alguno, en el orden del ciclo.
        semanas:   filas.flat_map { |f| f[:por_semana] }
                        .uniq { |w| w[:semana_label] }
                        .sort_by { |w| [Lotes::Nutricion::FASE_CORTA.keys.index(w[:fase]) || 99, w[:semana]] }
                        .map { |w| w[:semana_label] },
      }
    end

    # Los lotes que tienen algo para comparar (alguna fertilización), para el selector.
    def self.candidatos(club)
      con_reg  = RegistroAmbiental.where(club_id: club.id).where('nutricion IS NOT NULL OR fertilizacion = true').distinct.pluck(:lote_id)
      con_cama = club.lotes.where(cama_ciclo_id: CamaRegistro.where(club_id: club.id).where.not(nutricion: nil).select(:cama_ciclo_id)).pluck(:id)
      con_act  = LoteEvento.where(club_id: club.id, tipo: 'actividad', categoria: 'fertilizacion').distinct.pluck(:lote_id)
      club.lotes.where(id: (con_reg + con_cama + con_act).uniq).includes(:genetica).order(start_date: :desc).map do |l|
        { id: l.id, codigo: l.codigo, genetica_id: l.genetica_id, genetica: l.genetica&.nombre || l.strain,
          estado: l.estado, estado_label: l.estado_label, start_date: l.start_date,
          rendimiento_g: l.rendimiento_real_g&.to_f }
      end
    end

    def self.clave(p) = "#{p[:nombre].to_s.strip.downcase}|#{p[:unidad]}"

    private

    def clave(p) = self.class.clave(p)

    def fila(l, u)
      n = Lotes::Nutricion.new(l, con_costo: @con_costo).call
      pl = u.plantas[l.id] || {}
      cosechadas = pl[:cosechadas].to_i
      rend = l.rendimiento_real_g.to_f
      {
        id: l.id, codigo: l.codigo,
        genetica: l.genetica&.nombre || l.strain, automatica: l.automatica?,
        sala: l.sala&.nombre, sede: (l.sede || l.sala&.sede)&.nombre,
        estado: l.estado, estado_label: l.estado_label,
        plantas: n[:plantas],
        dias: (u.fases[l.id] || {}).slice('vegetativo', 'floracion', 'total'),
        rendimiento_g: rend.positive? ? rend.round(1) : nil,
        g_por_planta: rend.positive? && cosechadas.positive? ? (rend / cosechadas).round(1) : nil,
        g_m2: l.rendimiento_g_m2&.to_f,
        totales: n[:totales],
        # Por producto, indexado por su clave: la tabla busca la celda de cada lote.
        por_producto: n[:totales][:productos].to_h { |p| [clave(p), p] },
        por_fase: n[:por_fase],
        por_semana: n[:por_semana],
      }
    end
  end
end
