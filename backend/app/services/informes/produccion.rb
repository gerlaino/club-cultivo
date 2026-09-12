module Informes
  # EL INFORME DE PRODUCCIÓN ES DEL ADMIN, y contesta tres preguntas en tres marcos de tiempo:
  #
  #   1. Lo que se cosechó — del PERÍODO elegido, comparado con el anterior.
  #   2. Hoy en el cultivo — la foto de AHORA: qué hay en cada etapa y hace cuánto.
  #   3. Lo que viene — lo que está en floración, con fecha estimada de corte.
  #
  # Vivía en `InformesController#produccion` con cinco KPIs, y dos de los cinco estaban mal sin
  # que se notara: «Cosechados» contaba lotes `finalizado` por `updated_at` —editarle una nota a
  # un lote del año pasado lo traía al mes de hoy—, y «Plantas en pie» no excluía a las
  # descartadas (excluía `finalizado`, que no es un estado de planta). Un número plausible que no
  # es el real es el peor error de un informe: no se contradice con nada.
  #
  # COSECHADO ES CUANDO EL LOTE ENTRA A `cosecha` (decisión de Germán, sep-2026), y los gramos
  # pertenecen a ese período aunque se hayan pesado semanas después: lo que se cortó en agosto
  # rindió X, se sepa en agosto o en septiembre. Mientras no haya peso, el informe lo dice.
  class Produccion
    EN_PIE     = Lote::CULTIVO_ESTADOS                   # enraizado vegetativo floracion
    EN_PROCESO = %w[cosecha en_manicura curado].freeze   # ya cortado, todavía sin ser stock
    POST_COSECHA = %w[cosecha en_manicura curado finalizado].freeze

    # Etapas donde la planta cortada TODAVÍA EXISTE como planta: colgada secándose en `cosecha`,
    # y pesándose una por una en `en_manicura`. En `curado` ya es flor en frasco, y un número de
    # plantas ahí se leería como que hay plantas. Las que se cuentan son las que no se descartaron.
    CON_PLANTAS_CORTADAS = %w[cosecha en_manicura].freeze
    PLANTA_CORTADA       = %w[secado cosechado].freeze

    # Contra qué se mide «hace cuánto está ahí». El objetivo lo pone la genética y el lote lo
    # hereda al crearse (`LotesController#create`); si alguien lo cambió en el lote, manda ese.
    OBJETIVO_POR_ESTADO = {
      'vegetativo' => :dias_vegetativo_objetivo,
      'floracion'  => :dias_floracion_objetivo,
    }.freeze

    def initialize(club:, desde:, hasta:)
      @club  = club
      @desde = desde
      @hasta = hasta
    end

    def call
      periodo = cosechado_en(@desde, @hasta)
      duracion = (@hasta.to_date - @desde.to_date).to_i + 1
      anterior = cosechado_en(@desde - duracion.days, @desde - 1.second)

      {
        periodo:  periodo.merge(anterior: anterior.except(:lotes), variacion: variacion(periodo, anterior)),
        hoy:      hoy,
        por_sede: por_sede,
        proximas: proximas,
      }
    end

    # ── 1. Lo que se cosechó ───────────────────────────────────────────────────

    # Un lote «se cosechó» en la fecha de su PRIMER paso post-cosecha (cosecha, o en_manicura /
    # curado / finalizado para los lotes viejos que no registraron el corte). Nunca `updated_at`.
    def cosechado_en(desde, hasta)
      fechas = LoteEvento.where(lote_id: @club.lotes.select(:id), tipo: 'cambio_estado',
                                estado_nuevo: POST_COSECHA)
                         .group(:lote_id).minimum(:registrado_en)
      ids = fechas.select { |_, f| f >= desde && f <= hasta }.keys
      lotes = @club.lotes.where(id: ids).includes(:genetica, :sede, :lote_eventos).order(:codigo)

      filas = lotes.map { |l| fila_cosechado(l, fechas[l.id]) }
      con_peso = filas.select { |f| f[:gramos].to_f.positive? }
      gramos   = con_peso.sum { |f| f[:gramos] }.round(1)
      plantas  = con_peso.sum { |f| f[:plantas].to_i }

      {
        lotes:            filas,
        total_lotes:      filas.size,
        sin_peso:         filas.size - con_peso.size,
        gramos:           gramos,
        plantas:          plantas,
        gramos_por_planta: plantas.positive? ? (gramos / plantas).round(1) : nil,
      }
    end

    def fila_cosechado(lote, fecha)
      plantas = lote.plants_count_cosechadas || lote.plants_count
      gramos  = lote.rendimiento_real_g.to_f
      inicio  = lote.fecha_inicio_vegetativo || lote.start_date
      {
        id:        lote.id,
        codigo:    lote.codigo,
        genetica:  lote.genetica&.nombre,
        sede:      lote.sede&.nombre,
        fecha:     fecha.to_date,
        plantas:   plantas,
        gramos:    gramos.positive? ? gramos.round(1) : nil,
        gramos_por_planta: gramos.positive? && plantas.to_i.positive? ? (gramos / plantas).round(1) : nil,
        dias_ciclo: inicio ? (fecha.to_date - inicio.to_date).to_i : nil,
      }
    end

    # En porcentaje sobre el anterior. Sin anterior no hay variación —«▲ ∞ %» no le dice nada
    # a nadie—, y la pantalla dice «sin datos del período anterior».
    def variacion(actual, anterior)
      %i[gramos total_lotes plantas gramos_por_planta].to_h do |k|
        a = actual[k].to_f
        b = anterior[k].to_f
        [k, b.positive? ? (((a - b) / b) * 100).round(1) : nil]
      end
    end

    # ── 2. Hoy en el cultivo ───────────────────────────────────────────────────

    def hoy
      lotes = @club.lotes.where(estado: EN_PIE + EN_PROCESO).includes(:lote_eventos)
      plantas_por_estado = Plant.en_pie.joins(:lote).where(lotes: { club_id: @club.id })
                                .group('lotes.estado').count
      cortadas_por_estado = Plant.where(state: PLANTA_CORTADA).joins(:lote)
                                 .where(lotes: { club_id: @club.id, estado: CON_PLANTAS_CORTADAS })
                                 .group('lotes.estado').count

      por_estado = Lote::ESTADOS.filter_map do |estado|
        del_estado = lotes.select { |l| l.estado == estado }
        next if del_estado.empty?

        dias = del_estado.filter_map { |l| [l, l.dias_en_estado] if l.dias_en_estado }
        mas_viejo = dias.max_by(&:last)
        objetivo_attr = OBJETIVO_POR_ESTADO[estado]
        objetivo = objetivo_attr && mas_viejo && mas_viejo.first.public_send(objetivo_attr)

        {
          estado:      estado,
          lotes:       del_estado.size,
          plantas:     plantas_en_etapa(estado, plantas_por_estado, cortadas_por_estado),
          dias_promedio: dias.any? ? (dias.sum(&:last).to_f / dias.size).round : nil,
          mas_viejo:   mas_viejo && {
            codigo:   mas_viejo.first.codigo,
            dias:     mas_viejo.last,
            objetivo: objetivo,
            excedido: objetivo.present? && mas_viejo.last > objetivo,
          },
          rendimiento: del_estado.sum { |l| l.rendimiento_real_g.to_f }.round(1),
        }
      end

      # El KPI de arriba sigue siendo sólo lo que está EN PIE: lo cortado se cuenta en su fila.
      {
        plantas_en_pie:   plantas_por_estado.values.sum,
        lotes_en_pie:     lotes.count { |l| EN_PIE.include?(l.estado) },
        lotes_en_proceso: lotes.count { |l| EN_PROCESO.include?(l.estado) },
        por_estado:       por_estado,
        plan:             plan,
      }
    end

    # En pie mientras el lote está en cultivo; cortadas mientras siguen siendo plantas; nil en
    # curado — la pantalla y el PDF ponen «—», que no es lo mismo que cero.
    def plantas_en_etapa(estado, en_pie, cortadas)
      return en_pie[estado].to_i if EN_PIE.include?(estado)
      return cortadas[estado].to_i if CON_PLANTAS_CORTADAS.include?(estado)

      nil
    end

    # Sólo cuando el plan tiene tope (Básico). En Total no hay nada contra qué medir.
    #
    # OJO: el número que se muestra es EL MISMO que usa `PlanEnforcer` para bloquear el alta —
    # que hoy cuenta todas las plantas que existen, no sólo las en pie—. Si acá se mostrara otro,
    # el informe diría «queda lugar» y el alta rebotaría.
    def plan
      enforcer = PlanEnforcer.new(@club)
      info = enforcer.info
      tope = info[:limites][:plantas]
      return nil if tope.nil?

      { label: info[:label], tope: tope, cuentan: info[:uso][:plantas] }
    end

    def por_sede
      @club.sedes.includes(:salas).map do |s|
        plantas = Plant.en_pie.joins(lote: :sala).where(salas: { sede_id: s.id }).count
        # Flor seca solamente: los derivados (hash, preroll) tienen su propia unidad y no se
        # suman como gramos.
        flor = Stock.where(sede_id: s.id, forma_producto: 'flor_seca').disponibles.sum(:cantidad).to_f
        { id: s.id, nombre: s.nombre, salas: s.salas.cultivo.count,
          plantas: plantas, stock_disponible: flor.round(1) }
      end
    end

    # ── 3. Lo que viene ────────────────────────────────────────────────────────

    # Todo lo que está en floración, ordenado por fecha de corte. La fecha es la estimada del
    # lote, o entrada a floración + días objetivo; sin ninguna de las dos, «sin fecha» al final.
    # El estimado en gramos sale del g/planta HISTÓRICO de esa genética en esta organización;
    # sin historia no se estima y la fila lo dice — un número inventado se lee como promesa.
    def proximas
      lotes = @club.lotes.where(estado: 'floracion').includes(:genetica, :sala, :lote_eventos)
      plantas = Plant.en_pie.where(lote_id: lotes.map(&:id)).group(:lote_id).count
      gpp = gramos_por_planta_historico
      hoy = Time.zone.today

      lotes.map do |l|
        fecha = l.fecha_cosecha_estimada ||
                (l.fecha_inicio_floracion && l.dias_floracion_objetivo &&
                 l.fecha_inicio_floracion + l.dias_floracion_objetivo.days)
        n = plantas[l.id].to_i
        ref = gpp[l.genetica_id]
        {
          id:        l.id,
          codigo:    l.codigo,
          genetica:  l.genetica&.nombre,
          sala:      l.sala&.nombre,
          plantas:   n,
          fecha:     fecha,
          dias:      fecha && (fecha - hoy).to_i,
          gramos_por_planta_ref: ref,
          estimado:  ref && n.positive? ? (ref * n).round : nil,
        }
      end.sort_by { |p| [p[:fecha] ? 0 : 1, p[:fecha] || hoy] }
    end

    # Por genética: gramos ÷ plantas cosechadas, sobre los lotes de esta organización que ya
    # tienen las dos cosas. Un promedio de promedios pesaría igual un lote de 3 plantas que uno
    # de 40.
    def gramos_por_planta_historico
      @club.lotes.where('rendimiento_real_g > 0').where('plants_count_cosechadas > 0')
           .where.not(genetica_id: nil)
           .group(:genetica_id)
           .pluck(:genetica_id, Arel.sql('SUM(rendimiento_real_g)'), Arel.sql('SUM(plants_count_cosechadas)'))
           .to_h { |g, gramos, plantas| [g, (gramos.to_f / plantas).round(1)] }
    end
  end
end
