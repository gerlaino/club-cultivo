class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_analytics_access!, except: [:dispensador]
  before_action :require_dispensador_access!, only: [:dispensador]

  # GET /api/analytics/rendimiento_genetica
  # Para: admin, supervisor, super_admin
  def rendimiento_genetica
    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/rendimiento_genetica/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_rendimiento_genetica(club, año: año)
    end
    render json: data
  end

  def calcular_rendimiento_genetica(club, año: nil)
    lotes = club.lotes.where.not(estado: 'germinacion').includes(:genetica)
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # Rendimiento por genética (solo lotes con datos reales)
    por_genetica = lotes.group_by { |l| l.genetica_id }.filter_map do |gid, ls|
      genetica = ls.first&.genetica
      next unless genetica

      con_rendimiento = ls.select { |l| l.rendimiento_real_g.present? }
      rendimiento_avg = con_rendimiento.any? ? (con_rendimiento.sum { |l| l.rendimiento_real_g.to_f } / con_rendimiento.size).round(1) : nil

      objetivo_avg = begin
        obj = ls.select { |l| l.rendimiento_objetivo_g.present? }
        obj.any? ? (obj.sum { |l| l.rendimiento_objetivo_g.to_f } / obj.size).round(1) : nil
      end

      merma_avg = begin
        con_merma = ls.select { |l| l.plants_count.present? && l.plants_count_cosechadas.present? && l.plants_count > 0 }
        if con_merma.any?
          mermas = con_merma.map { |l| ((l.plants_count - l.plants_count_cosechadas).to_f / l.plants_count * 100).round(1) }
          (mermas.sum / mermas.size).round(1)
        end
      end

      con_ambos     = ls.select { |l| l.rendimiento_real_g.present? && l.plants_count.present? && l.plants_count > 0 }
      g_por_planta  = con_ambos.any? ? (con_ambos.sum { |l| l.rendimiento_real_g.to_f / l.plants_count } / con_ambos.size).round(1) : nil

      {
        genetica_id:          gid,
        nombre:               genetica.nombre,
        lotes_total:          ls.size,
        lotes_finalizados:    ls.count { |l| l.rendimiento_real_g.present? },
        rendimiento_promedio: rendimiento_avg,
        objetivo_promedio:    objetivo_avg,
        desviacion_promedio:  rendimiento_avg && objetivo_avg ? ((rendimiento_avg - objetivo_avg) / objetivo_avg * 100).round(1) : nil,
        merma_promedio_pct:   merma_avg,
        g_por_planta:         g_por_planta,
        lotes_activos:        ls.count { |l| !%w[germinacion finalizado].include?(l.estado) },
      }
    end.sort_by { |r| [-(r[:rendimiento_promedio] || 0)] }

    # Top lotes recientes
    lotes_recientes = club.lotes
                          .includes(:genetica)
                          .where.not(estado: %w[germinacion])
                          .order(created_at: :desc)
                          .limit(20)
                          .map do |l|
      {
        id:                  l.id,
        codigo:              l.codigo,
        estado:              l.estado,
        genetica:            l.genetica&.nombre,
        plants_count:        l.plants_count,
        rendimiento_real_g:  l.rendimiento_real_g&.to_f,
        rendimiento_obj_g:   l.rendimiento_objetivo_g&.to_f,
        g_por_planta:        l.rendimiento_real_g && l.plants_count.to_i > 0 ? (l.rendimiento_real_g.to_f / l.plants_count).round(1) : nil,
        desv_pct:            l.rendimiento_real_g && l.rendimiento_objetivo_g ? ((l.rendimiento_real_g.to_f - l.rendimiento_objetivo_g.to_f) / l.rendimiento_objetivo_g.to_f * 100).round(1) : nil,
        created_at:          l.created_at,
      }
    end

    # Resumen global
    lotes_finalizados = lotes.select { |l| l.rendimiento_real_g.present? }
    rendimiento_global = lotes_finalizados.any? ? (lotes_finalizados.sum { |l| l.rendimiento_real_g.to_f } / lotes_finalizados.size).round(1) : nil

    {
      resumen: {
        lotes_totales:        lotes.count,
        lotes_finalizados:    lotes_finalizados.size,
        geneticas_activas:    por_genetica.count { |g| g[:lotes_activos] > 0 },
        rendimiento_global_g: rendimiento_global,
      },
      por_genetica:    por_genetica,
      lotes_recientes: lotes_recientes,
    }
  end

  # GET /api/analytics/dispensador
  # Para: dispensador, admin
  def dispensador
    club = current_user.club
    data = Rails.cache.fetch("analytics/dispensador/#{club.id}/#{Date.today}", expires_in: 10.minutes) do
      calcular_dispensador(club)
    end
    render json: data
  end

  def calcular_dispensador(club)
    hoy    = Date.today
    inicio_semana = hoy.beginning_of_week
    inicio_mes    = hoy.beginning_of_month

    # Scope dispensaciones del club
    base_disps = Dispensacion.no_canceladas.joins(stock: :sede)
                             .where(sedes: { club_id: club.id })

    disps_hoy     = base_disps.where(fecha_dispensacion: hoy..hoy)
    disps_semana  = base_disps.where(fecha_dispensacion: inicio_semana..hoy)
    disps_mes     = base_disps.where(fecha_dispensacion: inicio_mes..hoy)

    # Stock por producto
    stocks = Stock.joins(:sede)
                  .where(sedes: { club_id: club.id })
                  .disponibles
                  .asignados
                  .includes(:lote)

    stock_bajo_umbral = club.umbral_stock_g.to_f
    stocks_data = stocks.group_by(&:forma_producto).map do |forma, ss|
      total = ss.sum { |s| s.cantidad.to_f }
      { forma: forma, cantidad_g: total.round(2), alerta: total < stock_bajo_umbral }
    end.sort_by { |s| s[:cantidad_g] }

    # Pacientes REPROCANN por vencer
    pacientes = Paciente.for_club(club.id)
    reprocann_por_vencer = pacientes.reprocann_por_vencer.count
    reprocann_vencidos   = pacientes.where('reprocann_vencimiento < ?', hoy).count

    # Top pacientes del mes
    top_pacientes = base_disps
      .where(fecha_dispensacion: inicio_mes..hoy)
      .includes(:paciente)
      .group(:paciente_id)
      .select('paciente_id, SUM(dispensaciones.cantidad) AS total_g, COUNT(*) AS dispens_count')
      .order('total_g DESC')
      .limit(10)
      .map do |r|
        p = r.paciente
        {
          iniciales:      "#{p&.nombre&.[](0)}.#{p&.apellido&.[](0)}.",
          dni_last4:      p&.dni_normalizado.to_s.last(4),
          total_g:        r.total_g.to_f.round(2),
          dispens_count:  r.dispens_count,
        }
      end

    por_dia = (6.days.ago.to_date..Date.today).map do |date|
      { fecha: date.strftime('%d/%m'), count: base_disps.where(fecha_dispensacion: date).count }
    end

    # Reservas a preparar: pendientes con fecha de entrega <= hoy (las de hoy + las vencidas).
    reservas_scope = Reserva.where(club_id: club.id).pendientes
    reservas_por_preparar = reservas_scope.where('fecha_entrega_estimada <= ?', hoy)
                                          .includes(:paciente, :stock)
                                          .order(fecha_entrega_estimada: :asc)
    reservas_lista = reservas_por_preparar.limit(20).map do |r|
      {
        id:             r.id,
        paciente:       r.paciente ? "#{r.paciente.nombre} #{r.paciente.apellido}".strip : '—',
        fecha:          r.fecha_entrega_estimada,
        vencida:        r.fecha_entrega_estimada < hoy,
        forma_producto: r.stock&.forma_producto,
        cantidad:       r.cantidad.to_f,
        sena_ars:       r.sena_ars.to_f,
        resta_ars:      r.aporte_restante_ars.to_f,
      }
    end

    {
      resumen: {
        dispensaciones_hoy:    disps_hoy.count,
        gramos_hoy:            disps_hoy.sum(:cantidad).to_f.round(2),
        dispensaciones_semana: disps_semana.count,
        gramos_semana:         disps_semana.sum(:cantidad).to_f.round(2),
        dispensaciones_mes:    disps_mes.count,
        gramos_mes:            disps_mes.sum(:cantidad).to_f.round(2),
      },
      reprocann: {
        por_vencer: reprocann_por_vencer,
        vencidos:   reprocann_vencidos,
      },
      stocks:        stocks_data,
      top_pacientes: top_pacientes,
      por_dia:       por_dia,
      reservas: {
        hoy:      reservas_por_preparar.where(fecha_entrega_estimada: hoy).count,
        vencidas: reservas_por_preparar.where('fecha_entrega_estimada < ?', hoy).count,
        total:    reservas_por_preparar.count,
        lista:    reservas_lista,
      },
    }
  end

  # GET /api/analytics/correlacion_ambiental
  # Para: admin, supervisor, super_admin
  def correlacion_ambiental
    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/correlacion_ambiental/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_correlacion_ambiental(club, año: año)
    end
    render json: data
  end

  # GET /api/analytics/produccion
  # Para: admin, supervisor, super_admin
  def produccion
    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/produccion/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_produccion(club, año: año)
    end
    render json: data
  end

  TIPOS_CORRELACION = %w[temperatura humedad vpd ph co2 ec ppfd].freeze

  VPD_BUCKETS = [
    [nil,  0.8, 'Bajo (<0.8 kPa)'],
    [0.8,  1.2, 'Óptimo bajo (0.8–1.2 kPa)'],
    [1.2,  1.6, 'Óptimo (1.2–1.6 kPa)'],
    [1.6,  2.0, 'Alto (1.6–2.0 kPa)'],
    [2.0,  nil, 'Muy alto (>2.0 kPa)'],
  ].freeze

  TEMP_BUCKETS = [
    [nil,  20.0, 'Frío (<20°C)'],
    [20.0, 23.0, 'Fresco (20–23°C)'],
    [23.0, 26.0, 'Óptimo (23–26°C)'],
    [26.0, 29.0, 'Cálido (26–29°C)'],
    [29.0, nil,  'Caliente (>29°C)'],
  ].freeze

  PH_BUCKETS = [
    [nil, 5.8, 'Ácido (<5.8)'],
    [5.8, 6.2, 'Óptimo (5.8–6.2)'],
    [6.2, 6.8, 'Normal (6.2–6.8)'],
    [6.8, nil, 'Alcalino (>6.8)'],
  ].freeze

  def calcular_correlacion_ambiental(club, año: nil)
    lotes = club.lotes
                .where(estado: 'finalizado')
                .where.not(rendimiento_real_g: nil)
                .includes(:genetica)
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # Precarga lecturas en memoria agrupadas por lote para evitar N+1
    lote_ids = lotes.map(&:id)
    lecturas_por_lote = LecturaAmbiental
      .where(lote_id: lote_ids)
      .group_by(&:lote_id)

    lotes_data = lotes.filter_map do |l|
      lecturas = lecturas_por_lote[l.id] || []
      next if lecturas.empty?

      promedios = TIPOS_CORRELACION.each_with_object({}) do |tipo, h|
        vals = lecturas.select { |r| r.tipo == tipo }.map { |r| r.valor.to_f }
        h[tipo.to_sym] = vals.any? ? (vals.sum / vals.size).round(2) : nil
      end
      next if promedios.values.all?(&:nil?)

      rend = l.rendimiento_real_g.to_f
      obj  = l.rendimiento_objetivo_g&.to_f

      {
        lote_id:       l.id,
        codigo:        l.codigo,
        genetica:      l.genetica&.nombre,
        rendimiento_g: rend,
        objetivo_g:    obj,
        desv_pct:      (obj && obj > 0) ? ((rend - obj) / obj * 100).round(1) : nil,
        n_registros:   lecturas.size,
        **promedios,
      }
    end.sort_by { |l| -(l[:rendimiento_g] || 0) }

    regresiones = TIPOS_CORRELACION.each_with_object({}) do |tipo, h|
      pairs = lotes_data.filter_map { |l| v = l[tipo.to_sym]; [v, l[:rendimiento_g]] if v }
      h[tipo.to_sym] = regresion_lineal(pairs.map(&:first), pairs.map(&:last))
    end

    {
      lotes:            lotes_data,
      vpd_buckets:      agrupar_buckets(lotes_data, :vpd,         VPD_BUCKETS),
      temp_buckets:     agrupar_buckets(lotes_data, :temperatura,  TEMP_BUCKETS),
      ph_buckets:       agrupar_buckets(lotes_data, :ph,           PH_BUCKETS),
      regresiones:,
      total_con_datos:  lotes_data.size,
      total_finalizados: lotes.count,
    }
  end

  def agrupar_buckets(lotes_data, campo, rangos)
    rangos.filter_map do |min, max, label|
      subset = lotes_data.select do |l|
        v = l[campo]
        next false if v.nil?
        (min.nil? || v >= min) && (max.nil? || v < max)
      end
      next if subset.empty?

      con_desv = subset.select { |l| l[:desv_pct] }
      {
        label:    label,
        count:    subset.size,
        rend_avg: (subset.sum { |l| l[:rendimiento_g] } / subset.size).round(1),
        desv_avg: con_desv.any? ? (con_desv.sum { |l| l[:desv_pct] } / con_desv.size).round(1) : nil,
      }
    end
  end

  def calcular_produccion(club, año: nil)
    lotes = club.lotes.includes(:genetica, :plants).where.not(estado: 'germinacion')
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # ── 1. PÉRDIDAS por cepa ───────────────────────────────────────
    perdidas_por_genetica = lotes.group_by(&:genetica_id).filter_map do |gid, ls|
      g = ls.first&.genetica
      next unless g

      con_datos = ls.select { |l| l.plants_count.present? && l.plants_count > 0 }
      next if con_datos.empty?

      mermas = con_datos.map do |l|
        cosechadas = l.plants_count_cosechadas || l.plants.where(state: 'cosechado').count
        descartadas = l.plants.where(state: 'descartada').count
        total = l.plants_count
        {
          lote_id:         l.id,
          lote_codigo:     l.codigo,
          total:           total,
          cosechadas:      cosechadas,
          descartadas:     descartadas,
          merma_pct:       total > 0 ? ((total - cosechadas).to_f / total * 100).round(1) : nil,
          descarte_pct:    total > 0 ? (descartadas.to_f / total * 100).round(1) : nil,
        }
      end

      merma_avg   = mermas.filter_map { |m| m[:merma_pct] }
      descarte_avg = mermas.filter_map { |m| m[:descarte_pct] }

      {
        genetica_id:      gid,
        nombre:           g.nombre,
        lotes_count:      ls.size,
        merma_promedio:   merma_avg.any? ? (merma_avg.sum / merma_avg.size).round(1) : nil,
        descarte_promedio: descarte_avg.any? ? (descarte_avg.sum / descarte_avg.size).round(1) : nil,
        por_lote:         mermas.sort_by { |m| m[:lote_codigo] },
      }
    end.sort_by { |r| [-(r[:merma_promedio] || 0)] }

    # ── 2. CICLOS — tiempo en cada fase por cepa ────────────────────
    # Usa lote_eventos para calcular días reales entre transiciones
    eventos_por_lote = LoteEvento
      .where(lote_id: lotes.map(&:id), tipo: 'cambio_estado')
      .order(:registrado_en)
      .group_by(&:lote_id)

    ciclos_por_lote = lotes.filter_map do |l|
      evs = eventos_por_lote[l.id] || []
      next if evs.empty? && l.start_date.nil?

      # start_date es siempre el ancla del período vegetativo total (incluye propagación)
      fase_inicio = {}
      fase_inicio['vegetativo'] = l.start_date&.to_time

      evs.each do |ev|
        next unless ev.estado_nuevo.present?
        # No sobreescribir 'vegetativo' — start_date es el inicio real del período completo.
        # Los eventos esqueje/semilla se guardan como sub-fases de propagación.
        next if ev.estado_nuevo == 'vegetativo'
        fase_inicio[ev.estado_nuevo] = ev.registrado_en
      end

      fases = %w[vegetativo floracion cosecha secado curado]
      dias = {}
      fases.each_with_index do |fase, idx|
        inicio = fase_inicio[fase]
        siguiente = fases[idx + 1]
        fin = siguiente ? fase_inicio[siguiente] : nil
        fin ||= Time.current if l.estado == fase
        dias[fase] = inicio && fin ? ((fin - inicio) / 86400.0).round(1) : nil
      end

      next if dias.values.all?(&:nil?)

      # ── Sub-fases de propagación (detalle dentro del período vegetativo) ──
      # propagacion = días desde start_date hasta transición a vegetativo pleno
      # vegetativo_puro = días desde vegetativo pleno hasta floracion
      ev_vegetativo = evs.find { |e| e.estado_nuevo == 'vegetativo' }
      if ev_vegetativo && l.start_date
        propagacion_dias = ((ev_vegetativo.registrado_en - l.start_date.to_time) / 86400.0).round(1)
        veg_puro_fin     = fase_inicio['floracion']
        veg_puro_fin   ||= Time.current if l.estado == 'vegetativo'
        veg_puro_dias    = veg_puro_fin ? ((veg_puro_fin - ev_vegetativo.registrado_en) / 86400.0).round(1) : nil
      else
        propagacion_dias = nil
        veg_puro_dias    = nil
      end

      {
        lote_id:        l.id,
        lote_codigo:    l.codigo,
        genetica_id:    l.genetica_id,
        propagacion:    propagacion_dias,
        vegetativo_puro: veg_puro_dias,
        **dias,
      }
    end

    ciclos_por_genetica = ciclos_por_lote.group_by { |c| c[:genetica_id] }.filter_map do |gid, cs|
      g = lotes.find { |l| l.genetica_id == gid }&.genetica
      next unless g

      fases = %w[vegetativo floracion cosecha secado curado]
      promedios = fases.map do |fase|
        vals = cs.filter_map { |c| c[fase] }
        [fase, vals.any? ? (vals.sum / vals.size).round(1) : nil]
      end.to_h

      # Promedios de sub-fases de propagación (solo para lotes que pasaron por esa etapa)
      prop_vals = cs.filter_map { |c| c[:propagacion] }
      veg_puro_vals = cs.filter_map { |c| c[:vegetativo_puro] }

      {
        genetica_id:     gid,
        nombre:          g.nombre,
        lotes_con_datos: cs.size,
        propagacion:     prop_vals.any? ? (prop_vals.sum / prop_vals.size).round(1) : nil,
        vegetativo_puro: veg_puro_vals.any? ? (veg_puro_vals.sum / veg_puro_vals.size).round(1) : nil,
        **promedios,
      }
    end.sort_by { |r| r[:nombre] }

    # ── 3. COMPARATIVA — lotes finalizados por cepa ─────────────────
    lotes_finalizados = lotes.select { |l| l.rendimiento_real_g.present? }
    comparativa = lotes_finalizados.group_by(&:genetica_id).filter_map do |gid, ls|
      g = ls.first&.genetica
      next unless g && ls.size >= 2

      {
        genetica_id: gid,
        nombre:      g.nombre,
        lotes:       ls.map { |l|
          {
            id:                l.id,
            codigo:            l.codigo,
            rendimiento_g:     l.rendimiento_real_g&.to_f,
            objetivo_g:        l.rendimiento_objetivo_g&.to_f,
            plants_count:      l.plants_count,
            grow_type:         l.grow_type,
            light_type:        l.light_type,
            start_date:        l.start_date,
          }
        }.sort_by { |l| l[:rendimiento_g] || 0 }.reverse,
      }
    end.sort_by { |r| r[:nombre] }

    {
      perdidas:    perdidas_por_genetica,
      ciclos:      ciclos_por_genetica,
      comparativa: comparativa,
    }
  end

  # GET /api/analytics/ejecutivo
  # Resumen anual — KPIs del año en curso vs año anterior
  def ejecutivo
    club         = current_user.club
    año_actual   = Time.zone.today.year
    año_anterior = año_actual - 1
    cache_key    = "analytics/ejecutivo/#{club.id}/#{año_actual}/#{analytics_stamp(club)}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      { año: año_actual, actual: kpis_anuales(club, año_actual), anterior: kpis_anuales(club, año_anterior) }
    end
    render json: data
  end

  # GET /api/analytics/pl_lotes
  # Para: admin, supervisor
  def pl_lotes
    club      = current_user.club
    cache_key = "analytics/pl_lotes/#{club.id}/#{analytics_stamp(club)}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_pl_lotes(club)
    end
    render json: data
  end

  def kpis_anuales(club, año)
    inicio = Date.new(año, 1, 1)
    fin    = Date.new(año, 12, 31)

    lotes_año = club.lotes
                    .where("EXTRACT(YEAR FROM COALESCE(start_date, created_at::date)) = ?", año)

    gramos_producidos = lotes_año.where.not(rendimiento_real_g: nil)
                                 .sum(:rendimiento_real_g).to_f.round(2)
    ciclos_cerrados   = lotes_año.where(estado: 'finalizado').count

    base_disps = Dispensacion.no_canceladas.joins(:stock)
                             .where(stocks: { club_id: club.id })
                             .where(fecha_dispensacion: inicio..fin)

    # Ingresos = libro contable de caja (MISMA definición que el dashboard de Negocio):
    # incluye recupero por dispensación Y señas/aportes, excluye crédito impago. Antes
    # se recomputaba desde Dispensacion (solo facturación), lo que dejaba las señas
    # afuera y contradecía el KPI mensual ("10000 arriba / sin ingresos abajo").
    ingresos           = MovimientoContable.ingresos.where(club_id: club.id)
                                           .where(fecha: inicio..fin).sum(:monto_ars).to_f.round(2)
    gramos_dispensados = base_disps.sum(:cantidad).to_f.round(2)

    costo_total = CostoLote.joins(:lote)
                           .where(lotes: { club_id: club.id })
                           .where("EXTRACT(YEAR FROM COALESCE(lotes.start_date, lotes.created_at::date)) = ?", año)
                           .sum(:costo_total).to_f.round(2)

    margen     = (ingresos - costo_total).round(2)
    margen_pct = ingresos > 0 ? (margen / ingresos * 100).round(1) : nil

    {
      gramos_producidos:,
      gramos_dispensados:,
      ingresos:,
      costo_total:,
      margen:,
      margen_pct:,
      ciclos_cerrados:,
    }
  end

  def pearson_r(xs, ys)
    n = xs.size
    return nil if n < 3

    mx = xs.sum.to_f / n
    my = ys.sum.to_f / n
    num = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
    den = Math.sqrt(xs.sum { |x| (x - mx)**2 } * ys.sum { |y| (y - my)**2 })
    return nil if den < 1e-10
    (num / den).round(3)
  rescue
    nil
  end

  def regresion_lineal(xs, ys)
    n = xs.size
    return nil if n < 3

    r = pearson_r(xs, ys)
    return nil unless r

    mx = xs.sum.to_f / n
    my = ys.sum.to_f / n
    ss_xy = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
    ss_xx = xs.sum { |x| (x - mx)**2 }
    return nil if ss_xx < 1e-10

    slope     = (ss_xy / ss_xx).round(4)
    intercept = (my - slope * mx).round(2)
    min_x     = xs.min.round(3)
    max_x     = xs.max.round(3)

    {
      r:,
      r_squared:   (r**2).round(3),
      slope:,
      intercept:,
      n:,
      x_min:       min_x,
      x_max:       max_x,
      y_at_xmin:   (slope * min_x + intercept).round(1),
      y_at_xmax:   (slope * max_x + intercept).round(1),
    }
  rescue
    nil
  end

  def calcular_pl_lotes(club)
    lotes = club.lotes.includes(:genetica, :costo_lote).order(created_at: :desc)

    ingresos_por_lote = Dispensacion.no_canceladas
      .joins(:stock)
      .where(stocks: { club_id: club.id })
      .where.not(stocks: { lote_id: nil })
      .group('stocks.lote_id')
      .sum('dispensaciones.cantidad * COALESCE(dispensaciones.precio_unitario_ars, 0)')

    gramos_disp_por_lote = Dispensacion.no_canceladas
      .joins(:stock)
      .where(stocks: { club_id: club.id })
      .where.not(stocks: { lote_id: nil })
      .group('stocks.lote_id')
      .sum(:cantidad)

    filas = lotes.map do |l|
      c           = l.costo_lote
      ingresos    = ingresos_por_lote[l.id].to_f.round(2)
      costo_total = c&.costo_total.to_f
      margen      = (ingresos - costo_total).round(2)
      margen_pct  = ingresos > 0 ? (margen / ingresos * 100).round(1) : nil
      gramos_disp = gramos_disp_por_lote[l.id].to_f.round(3)
      {
        id:                 l.id,
        codigo:             l.codigo,
        genetica:           l.genetica&.nombre,
        estado:             l.estado,
        costo_total:        costo_total,
        costo_por_gramo:    c&.costo_por_gramo&.to_f,
        ingresos:           ingresos,
        gramos_dispensados: gramos_disp,
        ingreso_por_gramo:  gramos_disp > 0 ? (ingresos / gramos_disp).round(2) : nil,
        margen:             margen,
        margen_pct:         margen_pct,
        tiene_costos:       c.present?,
        tiene_ingresos:     ingresos > 0,
      }
    end

    { lotes: filas }
  end

  # GET /api/analytics/contabilidad
  # P&L mensual últimos 12 meses + proyección de lotes en curso
  def contabilidad
    club = current_user.club
    cache_key = "analytics/contabilidad/#{club.id}/#{analytics_stamp(club)}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      calcular_contabilidad(club)
    end
    render json: data
  end

  # GET /api/analytics/comparativa_salas
  def comparativa_salas
    club     = current_user.club
    sala_ids = club.salas.pluck(:id)

    # Agregados por sala en una sola consulta
    stats_por_sala = Lote
      .where(sala_id: sala_ids, estado: 'finalizado')
      .group(:sala_id)
      .select(
        :sala_id,
        'COUNT(*) AS ciclos',
        'COALESCE(SUM(rendimiento_real_g), 0) AS total_g',
        'COALESCE(SUM(plants_count_cosechadas), 0) AS total_plantas',
      ).index_by(&:sala_id)

    # Días promedio usando lote_eventos (fecha real de finalización)
    dias_por_sala = LoteEvento
      .joins(:lote)
      .where(lotes: { sala_id: sala_ids })
      .where(tipo: 'cambio_estado', estado_nuevo: 'finalizado')
      .where.not('lotes.start_date': nil)
      .select("lotes.sala_id, AVG((lote_eventos.registrado_en::date - lotes.start_date)) AS dias_prom")
      .group('lotes.sala_id')
      .index_by(&:sala_id)

    activos_por_sala = Lote
      .where(sala_id: sala_ids)
      .where.not(estado: 'finalizado')
      .group(:sala_id)
      .count

    ultimas_lecturas = LecturaAmbiental
      .where(sala_id: sala_ids, tipo: %w[temperatura humedad co2])
      .where('medido_at >= ?', 24.hours.ago)
      .order(:sala_id, :tipo, medido_at: :desc)
      .select('DISTINCT ON (sala_id, tipo) sala_id, tipo, valor, medido_at')

    lecturas_por_sala = ultimas_lecturas.each_with_object({}) do |l, h|
      h[l.sala_id] ||= {}
      h[l.sala_id][l.tipo] = l.valor.to_f
    end

    salas = club.salas.order(:nombre)

    filas = salas.map do |sala|
      st          = stats_por_sala[sala.id]
      ciclos      = st&.ciclos.to_i
      total_g     = st&.total_g.to_f
      total_pls   = st&.total_plantas.to_i
      kg_producidos = total_g / 1000.0
      kg_por_planta = total_pls > 0 ? (total_g / total_pls / 1000.0).round(3) : nil
      dias_avg      = dias_por_sala[sala.id]&.dias_prom
      dias_promedio = dias_avg ? dias_avg.to_f.round(0).to_i : nil
      ambiental     = lecturas_por_sala[sala.id] || {}

      {
        id:             sala.id,
        nombre:         sala.nombre,
        tipo:           sala.tipo,
        ciclos:         ciclos,
        kg_producidos:  kg_producidos.round(3),
        kg_por_planta:  kg_por_planta,
        dias_promedio:  dias_promedio,
        lotes_activos:  activos_por_sala[sala.id] || 0,
        temperatura:    ambiental['temperatura'],
        humedad:        ambiental['humedad'],
        co2:            ambiental['co2'],
      }
    end

    render json: { salas: filas }
  end

  def require_analytics_access!
    unless %w[admin supervisor super_admin].include?(current_user.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  # Sello que cambia ante CUALQUIER mutación que afecte los números de la analítica
  # financiera/productiva del club: libro contable, costos de lote y lotes. Al
  # incluirlo en la cache key, la analítica se auto-invalida en el instante en que
  # cambian los datos (alta/edición/anulación de seña, dispensación, costo, fase de
  # lote) — sin callbacks ni busts manuales. El TTL queda como respaldo. Son 3
  # agregados baratos (max(updated_at) + count) sobre columnas indexadas por club.
  def analytics_stamp(club)
    mov = MovimientoContable.where(club_id: club.id)
    cl  = CostoLote.joins(:lote).where(lotes: { club_id: club.id })
    lo  = club.lotes
    [
      mov.maximum(:updated_at)&.to_i, mov.count,
      cl.maximum(:updated_at)&.to_i,  cl.count,
      lo.maximum(:updated_at)&.to_i,  lo.count,
    ].join('-')
  end

  def require_dispensador_access!
    unless %w[admin dispensador super_admin].include?(current_user.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def calcular_contabilidad(club)
    hoy   = Time.zone.today
    inicio = (hoy - 11.months).beginning_of_month

    # P&L mensual — agrupado por mes
    meses = []
    (0..11).each do |i|
      mes_ini = (hoy - i.months).beginning_of_month
      mes_fin = mes_ini.end_of_month
      label   = mes_ini.strftime('%b %Y')

      # Ingresos del mes desde el libro de caja (mismo criterio que el dashboard y
      # que kpis_anuales): dispensaciones cobradas + señas, sin crédito impago.
      ingresos = MovimientoContable.ingresos.where(club_id: club.id)
                                   .where(fecha: mes_ini..mes_fin).sum(:monto_ars).to_f.round(2)

      costos = CostoLote.joins(:lote)
                        .where(lotes: { club_id: club.id })
                        .where(created_at: mes_ini..mes_fin.end_of_day)
                        .sum(:costo_total).to_f.round(2)

      meses.unshift({ mes: label, mes_ini: mes_ini, ingresos: ingresos, costos: costos, margen: (ingresos - costos).round(2) })
    end

    # Proyección: lotes en curso (vegetativo / floración) × precio sugerido × rendimiento objetivo
    estados_en_curso = Lote::ESTADOS - ['finalizado']
    lotes_activos = club.lotes
                        .where(estado: estados_en_curso)
                        .where.not(rendimiento_objetivo_g: nil)

    proyeccion_items = lotes_activos.map do |l|
      precio_g = club.lotes
                     .joins(:costo_lote)
                     .where(genetica_id: l.genetica_id)
                     .where.not(rendimiento_real_g: nil)
                     .order(created_at: :desc)
                     .first
                     &.then { |ref| ref.rendimiento_real_g > 0 ? (CostoLote.find_by(lote: ref)&.costo_total.to_f / ref.rendimiento_real_g) : nil }

      ingreso_estimado = precio_g ? (l.rendimiento_objetivo_g * precio_g).round(2) : nil

      {
        lote_id:              l.id,
        codigo:               l.codigo,
        estado:               l.estado,
        genetica:             l.genetica&.nombre,
        rendimiento_obj_g:    l.rendimiento_objetivo_g.to_f,
        precio_g_estimado:    precio_g&.round(2),
        ingreso_estimado:     ingreso_estimado,
        fecha_cosecha_est:    l.fecha_cosecha_estimada,
      }
    end

    ingreso_proy_total = proyeccion_items.sum { |p| p[:ingreso_estimado] || 0 }.round(2)

    {
      meses:                meses,
      proyeccion_lotes:     proyeccion_items,
      ingreso_proy_total:   ingreso_proy_total,
    }
  end

  private :calcular_rendimiento_genetica, :calcular_dispensador, :calcular_correlacion_ambiental,
          :agrupar_buckets, :calcular_produccion, :calcular_pl_lotes, :kpis_anuales,
          :pearson_r, :regresion_lineal, :calcular_contabilidad,
          :require_analytics_access!, :require_dispensador_access!
end
